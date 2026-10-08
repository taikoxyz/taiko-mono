package rpc

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	opeth "github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/stretchr/testify/require"
)

func TestBlobServerResponseUnmarshalRejectsMalformedFields(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{
			name: "missing fields",
			body: `{}`,
		},
		{
			name: "wrong field types",
			body: `{"versionedHash":123,"commitment":456,"data":789}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var response BlobServerResponse
			require.NotPanics(t, func() {
				require.Error(t, json.Unmarshal([]byte(tt.body), &response))
			})
		})
	}
}

func TestBlobServerFallbackRejectsBlobDataNotMatchingRequestedHash(t *testing.T) {
	_, goodCommitment, goodHash := testBlobWithCommitment(t, []byte("expected derivation data"))
	badBlob, _, _ := testBlobWithCommitment(t, []byte("different derivation data"))

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/blobs/"+goodHash.String(), r.URL.Path)
		w.Header().Set("Content-Type", "application/json")
		require.NoError(t, json.NewEncoder(w).Encode(BlobServerResponse{
			VersionedHash: goodHash.String(),
			Commitment:    common.Bytes2Hex(goodCommitment[:]),
			Data:          badBlob.String(),
		}))
	}))
	defer server.Close()

	endpoint, err := url.Parse(server.URL)
	require.NoError(t, err)

	ds := NewBlobDataSource(context.Background(), &Client{}, endpoint)
	_, err = ds.GetBlobs(context.Background(), 0, []common.Hash{goodHash})
	require.ErrorContains(t, err, "blob server returned blob with versioned hash")
}

func TestGetBlobsFallsBackToBlobServerWhenBeaconMissesBlobs(t *testing.T) {
	blob, commitment, blobHash := testBlobWithCommitment(t, []byte("derivation data"))

	// The beacon node answers, but without the requested blob (e.g. pruned or not custodied).
	beacon := newBeaconStub()
	beacon.blobsBody = `{"execution_optimistic":false,"finalized":true,"data":[]}`
	beaconClient, err := NewBeaconClient(beacon.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/blobs/"+blobHash.String(), r.URL.Path)
		w.Header().Set("Content-Type", "application/json")
		require.NoError(t, json.NewEncoder(w).Encode(BlobServerResponse{
			VersionedHash: blobHash.String(),
			Commitment:    common.Bytes2Hex(commitment[:]),
			Data:          blob.String(),
		}))
	}))
	defer blobServer.Close()

	endpoint, err := url.Parse(blobServer.URL)
	require.NoError(t, err)

	ds := NewBlobDataSource(context.Background(), &Client{L1Beacon: beaconClient}, endpoint)
	blobs, err := ds.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{blob}, blobs)
	require.Len(t, beacon.blobRequests(), 1)
}

func TestGetBlobBytesReportsInvalidBlobBytesOnlyForUndecodableBlobs(t *testing.T) {
	// A blob matching its versioned hash but not the blob encoding is bad content: the default payload.
	var undecodable opeth.Blob
	undecodable[opeth.VersionOffset] = opeth.EncodingVersion + 1
	commitment, err := undecodable.ComputeKZGCommitment()
	require.NoError(t, err)
	undecodableHash := kzg4844.CalcBlobHashV1(sha256.New(), &commitment)

	beacon := newBeaconStub()
	beacon.blobsBody = blobsBody(t, &undecodable)
	beaconClient, err := NewBeaconClient(beacon.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)
	ds := NewBlobDataSource(context.Background(), &Client{L1Beacon: beaconClient}, nil)

	_, err = ds.GetBlobBytes(context.Background(), 100, []common.Hash{undecodableHash})
	require.ErrorIs(t, err, ErrInvalidBlobBytes)

	// A blob the beacon node does not serve is a fetch failure, which derivation must retry.
	_, _, missingHash := testBlobWithCommitment(t, []byte("missing"))
	_, err = ds.GetBlobBytes(context.Background(), 100, []common.Hash{missingHash})
	require.ErrorContains(t, err, "did not return blob")
	require.NotErrorIs(t, err, ErrInvalidBlobBytes)
}

func testBlobWithCommitment(t *testing.T, data []byte) (*opeth.Blob, kzg4844.Commitment, common.Hash) {
	t.Helper()

	var blob opeth.Blob
	require.NoError(t, blob.FromData(opeth.Data(data)))

	commitment, err := blob.ComputeKZGCommitment()
	require.NoError(t, err)

	return &blob, commitment, kzg4844.CalcBlobHashV1(sha256.New(), &commitment)
}
