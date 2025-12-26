package txlistfetcher

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// BlobFetcher is responsible for fetching the txList blob from the L1 block sidecar.
type BlobFetcher struct {
	cli        *rpc.Client
	dataSource *rpc.BlobDataSource
}

// NewBlobFetcher creates a new BlobFetcher instance based on the given rpc client.
func NewBlobFetcher(cli *rpc.Client, ds *rpc.BlobDataSource) *BlobFetcher {
	return &BlobFetcher{cli, ds}
}

// FetchPacaya implements the TxListFetcher interface.
func (d *BlobFetcher) FetchPacaya(ctx context.Context, meta metadata.TaikoBatchMetaDataPacaya) ([]byte, error) {
	if len(meta.GetBlobHashes()) == 0 {
		return nil, pkg.ErrBlobUnused
	}

	var blockNum uint64
	if meta.GetBlobCreatedIn().Int64() == 0 {
		blockNum = meta.GetProposedIn()
	} else {
		blockNum = meta.GetBlobCreatedIn().Uint64()
	}

	// Fetch the L1 block header with the given blob.
	l1Header, err := d.cli.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(blockNum))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch L1 header for block %d: %w", blockNum, err)
	}

	// Fetch the L1 block sidecars.
	sidecars, err := d.dataSource.GetBlobs(ctx, l1Header.Time, meta.GetBlobHashes())
	if err != nil {
		return nil, fmt.Errorf("failed to get blobs, errs: %w", err)
	}

	log.Info("Fetch sidecars", "blockNumber", blockNum, "sidecars", len(sidecars))

	var b []byte

	for _, sidecar := range sidecars {
		blob := eth.Blob(common.FromHex(sidecar.Blob))
		bytes, err := blob.ToData()
		if err != nil {
			return nil, err
		}
		b = append(b, bytes...)
	}
	if len(b) == 0 {
		return nil, pkg.ErrSidecarNotFound
	}

	return sliceTxList(meta.GetBatchID(), b, meta.GetTxListOffset(), meta.GetTxListSize())
}
