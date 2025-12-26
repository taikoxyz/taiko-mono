package rpc

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
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
	var tempMap map[string]interface{}
	if err := json.Unmarshal(data, &tempMap); err != nil {
		return err
	}

	// Parsing data based on different keys
	if versionedHash, ok := tempMap["versionedHash"]; ok {
		p.VersionedHash = versionedHash.(string)
	} else if versionedHash, ok := tempMap["versioned_hash"]; ok {
		p.VersionedHash = versionedHash.(string)
	}

	p.Commitment = tempMap["commitment"].(string)
	p.Data = tempMap["data"].(string)

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
			allSidecars[index] = &structs.Sidecar{
				KzgCommitment: value.KzgCommitment,
				Blob:          value.Blob,
			}
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

// getBlobFromServer get blob data from server path `/blob` or `/blobs`.
func (ds *BlobDataSource) getBlobFromServer(ctx context.Context, blobHashes []common.Hash) (*BlobDataSeq, error) {
	blobDataSeq := make([]*BlobData, 0, len(blobHashes))
	for _, blobHash := range blobHashes {
		requestURL, err := url.JoinPath(ds.blobServerEndpoint.String(), "/blobs/"+blobHash.String())
		if err != nil {
			return nil, err
		}
		resp, err := resty.New().R().
			SetResult(BlobServerResponse{}).
			SetContext(ctx).
			SetHeader("Content-Type", "application/json").
			SetHeader("Accept", "application/json").
			Get(requestURL)
		if err != nil {
			return nil, fmt.Errorf("failed to get blob from server, request URL: %s, err: %w", requestURL, err)
		}
		if !resp.IsSuccess() {
			return nil, fmt.Errorf(
				"unable to connect blobscan endpoint, status code: %v",
				resp.StatusCode(),
			)
		}
		response := resp.Result().(*BlobServerResponse)
		blobDataSeq = append(blobDataSeq, &BlobData{
			BlobHash:      response.VersionedHash,
			KzgCommitment: response.Commitment,
			Blob:          response.Data,
		})
	}
	return &BlobDataSeq{
		Data: blobDataSeq,
	}, nil
}
