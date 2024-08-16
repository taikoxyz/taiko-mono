package txlistdecoder

import (
	"context"

	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// TxListFetcher is responsible for fetching the L2 txList bytes from L1
type TxListFetcher interface {
	Fetch(ctx context.Context, tx *types.Transaction, meta metadata.TaikoBlockMetaData) ([]byte, error)
}
