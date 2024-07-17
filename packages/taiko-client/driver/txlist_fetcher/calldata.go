package txlistdecoder

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CalldataFetcher is responsible for fetching the txList bytes from the transaction's calldata.
type CalldataFetcher struct {
	rpc *rpc.Client
}

// Fetch fetches the txList bytes from the transaction's calldata.
func (d *CalldataFetcher) Fetch(
	_ context.Context,
	tx *types.Transaction,
	meta *bindings.TaikoDataBlockMetadata,
) ([]byte, error) {
	if meta.BlobUsed {
		return nil, pkg.ErrBlobUsed
	}

	return encoding.UnpackTxListBytes(tx.Data())
}

// FetchOntake fetches the txList bytes from the `CalldataTxList` event.
func (d *CalldataFetcher) FetchOntake(
	ctx context.Context,
	meta *bindings.TaikoDataBlockMetadata2,
) ([]byte, error) {
	if meta.BlobUsed {
		return nil, pkg.ErrBlobUsed
	}

	// Fetch the calldata txList from the event.
	iter, err := d.rpc.TaikoL1.FilterCalldataTxList(
		&bind.FilterOpts{Context: ctx, Start: meta.ProposedIn, End: &meta.ProposedIn},
		[]*big.Int{new(big.Int).SetUint64(meta.Id)},
	)
	if err != nil {
		return nil, err
	}
	for iter.Next() {
		return iter.Event.TxList, nil
	}

	return nil, fmt.Errorf("calldata for block %d not found", meta.Id)
}
