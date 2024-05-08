package rpc

import (
	"context"
	"fmt"
	"net/url"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"
	"github.com/prysmaticlabs/prysm/v4/beacon-chain/rpc/eth/blob"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
)

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

// GetBlobs get blob sidecar by meta
func (ds *BlobDataSource) GetBlobs(
	ctx context.Context,
	meta *bindings.TaikoDataBlockMetadata,
) ([]*blob.Sidecar, error) {
	if !meta.BlobUsed {
		return nil, pkg.ErrBlobUnused
	}

	var (
		sidecars []*blob.Sidecar
		err      error
	)
	if ds.client.L1Beacon == nil {
		sidecars, err = nil, pkg.ErrBeaconNotFound
	} else {
		sidecars, err = ds.client.L1Beacon.GetBlobs(ctx, meta.Timestamp)
	}
	if err != nil {
		log.Info("Failed to get blobs from beacon, try to use blob server.", "error", err.Error())
		if ds.blobServerEndpoint == nil {
			log.Info("No blob server endpoint set")
			return nil, err
		}
		blobs, err := ds.getBlobFromServer(ctx, meta.BlobHash)
		if err != nil {
			return nil, err
		}
		sidecars = make([]*blob.Sidecar, len(blobs.Data))
		for index, value := range blobs.Data {
			sidecars[index] = &blob.Sidecar{
				KzgCommitment: value.KzgCommitment,
				Blob:          value.Blob,
			}
		}
	}
	return sidecars, nil
}

// getBlobFromServer get blob data from server path `/getBlob`.
func (ds *BlobDataSource) getBlobFromServer(ctx context.Context, blobHash common.Hash) (*BlobDataSeq, error) {
	var (
		route = "/getBlob"
		param = map[string]string{"blobHash": blobHash.String()}
	)
	requestURL, err := url.JoinPath(ds.blobServerEndpoint.String(), route)
	if err != nil {
		return nil, err
	}
	resp, err := resty.New().R().
		SetResult(BlobDataSeq{}).
		SetQueryParams(param).
		SetContext(ctx).
		SetHeader("Content-Type", "application/json").
		SetHeader("Accept", "application/json").
		Get(requestURL)
	if err != nil {
		return nil, err
	}
	if !resp.IsSuccess() {
		return nil, fmt.Errorf(
			"unable to connect blob server endpoint, status code: %v",
			resp.StatusCode(),
		)
	}
	return resp.Result().(*BlobDataSeq), nil
}
