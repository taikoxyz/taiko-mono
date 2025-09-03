package manifestFetcher

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// ManifestFetcher is responsible for fetching the L2 manifest from L1 blob
type ManifestFetcher interface {
	FetchShasta(ctx context.Context, meta metadata.TaikoProposalMetaDataShasta) ([]byte, error)
}
