package txlistfetcher

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// TxListFetcher is responsible for fetching the L2 txList bytes from L1
type TxListFetcher interface {
	FetchOntake(ctx context.Context, meta metadata.TaikoBlockMetaDataOntake) ([]byte, error)
	FetchPacaya(ctx context.Context, meta metadata.TaikoBatchMetaDataPacaya) ([]byte, error)
}
