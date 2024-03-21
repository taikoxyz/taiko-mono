package txlistdecoder

import (
	"context"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
)

// CalldataFetcher is responsible for fetching the txList bytes from the transaction's calldata.
type CalldataFetcher struct{}

// NewCalldataTxListFetcher creates a new CalldataFetcher instance.
func (d *CalldataFetcher) Fetch(
	_ context.Context,
	tx *types.Transaction,
	meta *bindings.TaikoDataBlockMetadata,
) ([]byte, error) {
	if meta.BlobUsed {
		return nil, errBlobUsed
	}

	return encoding.UnpackTxListBytes(tx.Data())
}
