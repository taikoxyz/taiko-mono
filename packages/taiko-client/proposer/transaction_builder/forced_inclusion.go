package builder

import (
	bindingTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/binding_types"
)

// buildParamsForForcedInclusion builds the blob params and the block params
// for the given forced inclusion.
func buildParamsForForcedInclusion(
	forcedInclusion bindingTypes.IForcedInclusionStoreForcedInclusion,
) (bindingTypes.ITaikoInboxBlobParams, []bindingTypes.ITaikoInboxBlockParams) {
	if forcedInclusion == nil {
		return nil, nil
	}

	blobParams := bindingTypes.NewBlobParams(
		[][32]byte{forcedInclusion.BlobHash()},
		0,
		0,
		forcedInclusion.BlobByteOffset(),
		forcedInclusion.BlobByteSize(),
		forcedInclusion.BlobCreatedIn(),
	)

	return blobParams, []bindingTypes.ITaikoInboxBlockParams{bindingTypes.NewBlockParams(
		0, 0, make([][32]byte, 0),
	)}
}
