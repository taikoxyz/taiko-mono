package rpc

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"
	"github.com/prysmaticlabs/prysm/v5/api/server/structs"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
)

var ErrInvalidBlobBytes = errors.New("invalid blob bytes")

type BlobDataSource struct {
	ctx                context.Context
	client             *Client
	blobServerEndpoint *url.URL
}

type BlobData struct {
	BlobHash      string `json:"blob_hash"`
	KzgCommitment string `json:"kzg_commitment"`
	Blob          string `json:"blob"`
}

type BlobDataSeq struct {
	Data []*BlobData `json:"data"`
}

type BlobServerResponse struct {
	Commitment    string `json:"commitment"`
	Data          string `json:"data"`
	VersionedHash string `json:"versionedHash"`
}

func NewBlobDataSource(
	ctx context.Context,
	client *Client,
	blobServerEndpoint *url.URL,
) *BlobDataSource {
	return &BlobDataSource{
		ctx:                ctx,
		client:             client,
		blobServerEndpoint: blobServerEndpoint,
	}
}

// UnmarshalJSON overwrites to parse data based on different json keys
func (p *BlobServerResponse) UnmarshalJSON(data []byte) error {
	var response struct {
		Commitment          string `json:"commitment"`
		Data                string `json:"data"`
		VersionedHash       string `json:"versionedHash"`
		VersionedHashLegacy string `json:"versioned_hash"`
	}
	if err := json.Unmarshal(data, &response); err != nil {
		return err
	}

	p.VersionedHash = response.VersionedHash
	if p.VersionedHash == "" {
		p.VersionedHash = response.VersionedHashLegacy
	}
	p.Commitment = response.Commitment
	p.Data = response.Data

	if p.VersionedHash == "" {
		return errors.New("missing versioned hash in blob server response")
	}
	if p.Commitment == "" {
		return errors.New("missing commitment in blob server response")
	}
	if p.Data == "" {
		return errors.New("missing data in blob server response")
	}

	return nil
}

// GetBlobBytes get the bytes of required blobs
func (ds *BlobDataSource) GetBlobBytes(
	ctx context.Context,
	timestamp uint64,
	blobHashes []common.Hash,
) ([]byte, error) {
	sidecars, err := ds.GetSidecars(ctx, timestamp, blobHashes)
	if err != nil {
		return nil, err
	}
	var b []byte
	for _, sidecar := range sidecars {
		blob := eth.Blob(common.FromHex(sidecar.Blob))
		bytes, err := blob.ToData()
		if err != nil {
			return nil, errors.Join(ErrInvalidBlobBytes, err)
		}
		b = append(b, bytes...)
	}
	if len(b) == 0 {
		return nil, pkg.ErrSidecarNotFound
	}
	return b, nil
}

// GetSidecars get blob sidecar by meta
func (ds *BlobDataSource) GetSidecars(
	ctx context.Context,
	timestamp uint64,
	blobHashes []common.Hash,
) ([]*structs.Sidecar, error) {
	var (
		sidecars    []*structs.Sidecar
		allSidecars []*structs.Sidecar
		err         error
	)
	if ds.client.L1Beacon == nil {
		err = pkg.ErrBeaconNotFound
	} else {
		allSidecars, err = ds.client.L1Beacon.GetBlobs(ctx, timestamp)
	}
	if err != nil {
		if !errors.Is(err, pkg.ErrBeaconNotFound) {
			log.Info("Failed to get blobs from beacon, try to use blob server", "timestamp", timestamp, "error", err.Error())
		}
		if ds.blobServerEndpoint == nil {
			log.Info("No blob server endpoint set")
			return nil, err
		}
		blobs, err := ds.getBlobFromServer(ctx, blobHashes)
		if err != nil {
			return nil, err
		}
		allSidecars = make([]*structs.Sidecar, len(blobs.Data))
		for index, value := range blobs.Data {
			sidecar, err := sidecarFromBlobServer(value, blobHashes[index])
			if err != nil {
				return nil, err
			}
			allSidecars[index] = sidecar
		}
	}
	for _, blobHash := range blobHashes {
		// Compare the blob hash with the sidecar's kzg commitment.
		for j, sidecar := range allSidecars {
			log.Debug(
				"Block sidecar",
				"index", j,
				"KzgCommitment", sidecar.KzgCommitment,
				"blobHash", blobHash,
			)

			commitment := kzg4844.Commitment(common.FromHex(sidecar.KzgCommitment))
			if kzg4844.CalcBlobHashV1(sha256.New(), &commitment) == blobHash {
				sidecars = append(sidecars, sidecar)
				break
			}
		}
	}

	if len(sidecars) != len(blobHashes) {
		return nil, fmt.Errorf("blob sidecar count mismatch: expected %d, got %d", len(blobHashes), len(sidecars))
	}
	return sidecars, nil
}

// sidecarFromBlobServer rebuilds the sidecar from blob bytes and verifies it
// against the requested versioned hash instead of trusting blob-server metadata.
func sidecarFromBlobServer(blobData *BlobData, expectedHash common.Hash) (*structs.Sidecar, error) {
	if blobData == nil {
		return nil, errors.New("nil blob data from blob server")
	}

	blobHex := blobData.Blob
	if !strings.HasPrefix(blobHex, "0x") {
		blobHex = "0x" + blobHex
	}

	blobBytes, err := hexutil.Decode(blobHex)
	if err != nil {
		return nil, fmt.Errorf("invalid blob bytes from blob server: %w", err)
	}
	if len(blobBytes) != eth.BlobSize {
		return nil, fmt.Errorf("invalid blob length from blob server: expected %d, got %d", eth.BlobSize, len(blobBytes))
	}

	var blob eth.Blob
	copy(blob[:], blobBytes)

	commitment, err := blob.ComputeKZGCommitment()
	if err != nil {
		return nil, fmt.Errorf("failed to compute KZG commitment from blob server data: %w", err)
	}

	blobHash := kzg4844.CalcBlobHashV1(sha256.New(), &commitment)
	if blobHash != expectedHash {
		return nil, fmt.Errorf("blob server returned blob with versioned hash %s, expected %s", blobHash, expectedHash)
	}

	return &structs.Sidecar{
		KzgCommitment: common.Bytes2Hex(commitment[:]),
		Blob:          blob.String(),
	}, nil
}

// getBlobFromServer get blob data from server path `/blob` or `/blobs`.
func (ds *BlobDataSource) getBlobFromServer(ctx context.Context, blobHashes []common.Hash) (*BlobDataSeq, error) {
	blobDataSeq := make([]*BlobData, 0, len(blobHashes))
	for _, blobHash := range blobHashes {
		blobData, err := ds.getBlobByHash(ctx, blobHash)
		if err != nil {
			return nil, err
		}
		blobDataSeq = append(blobDataSeq, blobData)
	}
	return &BlobDataSeq{
		Data: blobDataSeq,
	}, nil
}

// GetBlobDataByHash gets the blob data by the given blob hash.
func (ds *BlobDataSource) getBlobByHash(ctx context.Context, blobHash common.Hash) (*BlobData, error) {
	requestURL, err := url.JoinPath(ds.blobServerEndpoint.String(), "/blobs/"+blobHash.String())
	if err != nil {
		return nil, err
	}

	resp, restErr := resty.New().R().
		SetResult(BlobServerResponse{}).
		SetContext(ctx).
		SetHeader("Content-Type", "application/json").
		SetHeader("Accept", "application/json").
		Get(requestURL)
	if restErr == nil && resp.IsSuccess() {
		response := resp.Result().(*BlobServerResponse)
		return &BlobData{
			BlobHash:      response.VersionedHash,
			KzgCommitment: response.Commitment,
			Blob:          response.Data,
		}, nil
	}

	if restErr == nil {
		restErr = fmt.Errorf("unable to connect blobscan endpoint, status code: %v", resp.StatusCode())
	} else {
		restErr = fmt.Errorf("failed to get blob from server, request URL: %s, err: %w", requestURL, restErr)
	}

	blob, anvilErr := ds.client.L1.AnvilGetBlobByHash(ctx, blobHash)
	if anvilErr != nil {
		return nil, fmt.Errorf(
			"failed to fetch blob %s from blob server and anvil RPC: %w", blobHash, errors.Join(restErr, anvilErr),
		)
	}

	commitment, err := blob.ComputeKZGCommitment()
	if err != nil {
		return nil, fmt.Errorf("failed to compute KZG commitment for blob %s: %w", blobHash, err)
	}

	return &BlobData{
		BlobHash:      blobHash.String(),
		KzgCommitment: common.Bytes2Hex(commitment[:]),
		Blob:          blob.String(),
	}, nil
}
