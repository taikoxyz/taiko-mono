package txlistdecoder

import (
	"context"
	"errors"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

var (
	errBlobUsed        = errors.New("blob is used")
	errBlobUnused      = errors.New("blob is not used")
	errSidecarNotFound = errors.New("sidecar not found")
)

type TxListFetcher interface {
	Fetch(ctx context.Context, tx *types.Transaction, meta *bindings.TaikoDataBlockMetadata) ([]byte, error)
}
