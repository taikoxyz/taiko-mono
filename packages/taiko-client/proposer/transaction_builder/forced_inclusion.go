package builder

import (
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/params"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// buildParamsForForcedInclusion builds the blob params and the block params
// for the given forced inclusion.
func buildParamsForForcedInclusion[
	T *pacayaBindings.IForcedInclusionStoreForcedInclusion | *shastaBindings.IForcedInclusionStoreForcedInclusion,
](
	forcedInclusion T,
	minTxsPerForcedInclusion *big.Int,
) (params.ITaikoInboxBlobParams, []params.ITaikoInboxBlockParams) {
	if forcedInclusion == nil {
		return nil, nil
	}

	var blobParams *params.BlobParams
	switch s := any(forcedInclusion).(type) {
	case *pacayaBindings.IForcedInclusionStoreForcedInclusion:
		blobParams = params.NewBlobParams(
			[][32]byte{s.BlobHash},
			0,
			0,
			s.BlobByteOffset,
			s.BlobByteSize,
			s.BlobCreatedIn,
		)
	case *shastaBindings.IForcedInclusionStoreForcedInclusion:
		blobParams = params.NewBlobParams(
			[][32]byte{s.BlobHash},
			0,
			0,
			s.BlobByteOffset,
			s.BlobByteSize,
			s.BlobCreatedIn,
		)
	}
	return blobParams, []params.ITaikoInboxBlockParams{params.NewBlockParams(
		uint16(minTxsPerForcedInclusion.Uint64()), 0, make([][32]byte, 0),
	)}
}
