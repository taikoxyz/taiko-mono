package txlistdecoder

import (
	"context"
	"errors"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-client/bindings"
)

var (
	errBlobUsed        = errors.New("blob is used")
	errBlobUnused      = errors.New("blob is not used")
	errSidecarNotFound = errors.New("sidecar not found")
)

// TxListFetcher is responsible for fetching the L2 txList bytes from L1
type TxListFetcher interface {
	Fetch(ctx context.Context, tx *types.Transaction, meta *bindings.TaikoDataBlockMetadata) ([]byte, error)
}
