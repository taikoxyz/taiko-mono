package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"
	"github.com/prysmaticlabs/prysm/v5/api/server/structs"
)

type BlobDataSource struct {
	ctx                context.Context
	client             *Client
	blobServerEndpoint *url.URL
}

const (
	blobFetchRetryInterval        = time.Second
	blobFetchMaxRetries    uint64 = 5
)

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

// GetBlobs get blob sidecar by meta
func (ds *BlobDataSource) GetBlobs(
	ctx context.Context,
	timestamp uint64,
	blobHashes []common.Hash,
) ([]*structs.Sidecar, error) {
	var (
		sidecars []*structs.Sidecar
		err      error
	)
	// if ds.client.L1Beacon == nil {
	// 	sidecars, err = nil, pkg.ErrBeaconNotFound
	// } else {
	// 	sidecars, err = ds.client.L1Beacon.GetBlobs(ctx, timestamp)
	// }
	// if err != nil {
	// if !errors.Is(err, pkg.ErrBeaconNotFound) {
	// 	log.Info("Failed to get blobs from beacon, try to use blob server", "timestamp", timestamp, "error", err.Error())
	// }

	if ds.blobServerEndpoint == nil {
		log.Info("No blob server endpoint set")
		return nil, err
	}
	blobs, err := ds.getBlobFromMServer(ctx, blobHashes)
	if err != nil {
		return nil, err
	}
	sidecars = make([]*structs.Sidecar, len(blobs.Data))
	for index, value := range blobs.Data {
		sidecars[index] = &structs.Sidecar{
			KzgCommitment: value.KzgCommitment,
			Blob:          value.Blob,
		}
	}
	// }

	return sidecars, nil
}

// getBlobFromMServer gets blob data from the m-server `/blobs/{hash}` endpoint with retry semantics.
func (ds *BlobDataSource) getBlobFromMServer(ctx context.Context, blobHashes []common.Hash) (*BlobDataSeq, error) {
	blobDataSeq := make([]*BlobData, 0, len(blobHashes))
	restyClient := resty.New()
	for _, blobHash := range blobHashes {
		requestURL, err := url.JoinPath(ds.blobServerEndpoint.String(), "/blobs/"+blobHash.String())
		if err != nil {
			return nil, err
		}
		var blobResp *BlobServerResponse
		op := func() error {
			resp, err := restyClient.R().
				SetResult(BlobServerResponse{}).
				SetContext(ctx).
				SetHeader("Content-Type", "application/json").
				SetHeader("Accept", "application/json").
				Get(requestURL)
			if err != nil {
				log.Warn("Failed to get blob from m-server, retrying", "hash", blobHash.Hex(), "url", requestURL, "error", err)
				return err
			}
			if !resp.IsSuccess() {
				err := fmt.Errorf(
					"unable to connect blobscan endpoint, status code: %v",
					resp.StatusCode(),
				)
				log.Warn("Blob m-server returned non-success status", "hash", blobHash.Hex(), "url", requestURL, "status", resp.StatusCode())
				return err
			}
			blobResp = resp.Result().(*BlobServerResponse)
			return nil
		}
		if err := backoff.Retry(
			op,
			backoff.WithContext(
				backoff.WithMaxRetries(backoff.NewConstantBackOff(blobFetchRetryInterval), blobFetchMaxRetries),
				ctx,
			),
		); err != nil {
			return nil, fmt.Errorf("failed to get blob from server, request URL: %s, err: %w", requestURL, err)
		}

		blobDataSeq = append(blobDataSeq, &BlobData{
			BlobHash:      blobResp.VersionedHash,
			KzgCommitment: blobResp.Commitment,
			Blob:          blobResp.Data,
		})
	}
	return &BlobDataSeq{
		Data: blobDataSeq,
	}, nil
}
