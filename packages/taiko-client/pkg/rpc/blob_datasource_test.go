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
	_, err = ds.GetSidecars(context.Background(), 0, []common.Hash{goodHash})
	require.ErrorContains(t, err, "blob server returned blob with versioned hash")
}

func testBlobWithCommitment(t *testing.T, data []byte) (*opeth.Blob, kzg4844.Commitment, common.Hash) {
	t.Helper()

	var blob opeth.Blob
	require.NoError(t, blob.FromData(opeth.Data(data)))

	commitment, err := blob.ComputeKZGCommitment()
	require.NoError(t, err)

	return &blob, commitment, kzg4844.CalcBlobHashV1(sha256.New(), &commitment)
}
