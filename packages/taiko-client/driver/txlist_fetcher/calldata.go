package txlistdecoder

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CalldataFetcher is responsible for fetching the txList bytes from the transaction's calldata.
type CalldataFetcher struct {
	rpc *rpc.Client
}

// NewCalldataFetch creates a new CalldataFetcher instance based on the given rpc client.
func NewCalldataFetch(rpc *rpc.Client) *CalldataFetcher {
	return &CalldataFetcher{rpc: rpc}
}

// Fetch fetches the txList bytes from the transaction's calldata.
func (d *CalldataFetcher) Fetch(
	ctx context.Context,
	tx *types.Transaction,
	meta metadata.TaikoBlockMetaData,
) ([]byte, error) {
	if meta.GetBlobUsed() {
		return nil, pkg.ErrBlobUsed
	}

	// If the given L2 block is not an ontake block, decode the txlist from calldata directly.
	if !meta.IsOntakeBlock() {
		return encoding.UnpackTxListBytes(tx.Data())
	}

	// Otherwise, fetch the txlist data from the `CalldataTxList` event.
	end := meta.GetRawBlockHeight().Uint64()
	iter, err := d.rpc.V2.TaikoL1.FilterCalldataTxList(
		&bind.FilterOpts{Context: ctx, Start: meta.GetRawBlockHeight().Uint64(), End: &end},
		[]*big.Int{meta.GetBlockID()},
	)
	if err != nil {
		return nil, err
	}
	for iter.Next() {
		return iter.Event.TxList, nil
	}

	return nil, fmt.Errorf("calldata for block %d not found", meta.GetBlockID())
}
