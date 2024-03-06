package txlistdecoder

import (
	"context"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

type CalldataFetcher struct{}

func (d *CalldataFetcher) Fetch(
	ctx context.Context,
	tx *types.Transaction,
	meta *bindings.TaikoDataBlockMetadata,
) ([]byte, error) {
	if meta.BlobUsed {
		return nil, errBlobUsed
	}

	return encoding.UnpackTxListBytes(tx.Data())
}
