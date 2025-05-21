package builder

import (
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/params"
)

// buildParamsForForcedInclusion builds the blob params and the block params
// for the given forced inclusion.
func buildParamsForForcedInclusion(
	forcedInclusion params.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
) (params.ITaikoInboxBlobParams, []params.ITaikoInboxBlockParams) {
	if forcedInclusion == nil {
		return nil, nil
	}

	blobParams := params.NewBlobParams(
		[][32]byte{forcedInclusion.BlobHash()},
		0,
		0,
		forcedInclusion.BlobByteOffset(),
		forcedInclusion.BlobByteSize(),
		forcedInclusion.BlobCreatedIn(),
	)

	return blobParams, []params.ITaikoInboxBlockParams{params.NewBlockParams(
		uint16(minTxsPerForcedInclusion.Uint64()), 0, make([][32]byte, 0),
	)}
}
