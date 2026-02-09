package txlistfetcher

import (
	"context"
	"fmt"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CalldataFetcher is responsible for fetching the txList bytes from the transaction's calldata.
type CalldataFetcher struct {
	rpc *rpc.Client
}

// NewCalldataFetcher creates a new CalldataFetcher instance based on the given rpc client.
func NewCalldataFetcher(rpc *rpc.Client) *CalldataFetcher {
	return &CalldataFetcher{rpc: rpc}
}

// FetchPacaya fetches the txList bytes from the transaction's calldata, by parsing the `BatchProposed` event.
func (d *CalldataFetcher) FetchPacaya(ctx context.Context, meta metadata.TaikoBatchMetaDataPacaya) ([]byte, error) {
	if len(meta.GetBlobHashes()) != 0 {
		return nil, pkg.ErrBlobUsed
	}

	// Fetch the txlist data from the `BatchProposed` event.
	end := meta.GetRawBlockHeight().Uint64()
	iter, err := d.rpc.PacayaClients.TaikoInbox.FilterBatchProposed(
		&bind.FilterOpts{Context: ctx, Start: meta.GetRawBlockHeight().Uint64(), End: &end},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create batch proposed filter: %w", err)
	}
	for iter.Next() {
		if iter.Event.Meta.BatchId != meta.GetBatchID().Uint64() {
			continue
		}
		return sliceTxList(meta.GetBatchID(), iter.Event.TxList, meta.GetTxListOffset(), meta.GetTxListSize())
	}

	if iter.Error() != nil {
		return nil, fmt.Errorf("failed to fetch calldata for batch %d: %w", meta.GetBatchID(), iter.Error())
	}

	return nil, fmt.Errorf("calldata for batch %d not found", meta.GetBatchID())
}
