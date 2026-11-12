package derivation

import (
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// PrepareSourcePayload applies forced metadata before validation and replaces invalid sources
// wholesale with one empty block inheriting metadata from the actual parent.
func PrepareSourcePayload(
	cli *rpc.Client,
	sourcePayload *DerivationSourcePayload,
	parent *types.Block,
	meta metadata.TaikoProposalMetaDataShasta,
	parentAnchorBlockNumber uint64,
	isForcedInclusion bool,
) {
	sourcePayload.ParentBlock = parent
	sourcePayload.IsForcedInclusion = isForcedInclusion
	// Forced sources retain their candidates while inheriting metadata before validation.
	if sourcePayload.IsForcedInclusion {
		ApplyInheritedMetadata(
			sourcePayload,
			meta.GetEventData(),
			meta.GetTimestamp(),
			parentAnchorBlockNumber,
			cli.L2.ChainID,
		)
	}

	if !ValidateMetadata(
		cli,
		sourcePayload,
		meta.GetEventData(),
		meta.GetTimestamp(),
		meta.GetRawBlockHeight().Uint64()-1,
		parentAnchorBlockNumber,
		sourcePayload.IsForcedInclusion,
	) {
		sourcePayload.Default = true
		sourcePayload.BlockPayloads = []*BlockPayload{
			{BlockManifest: manifest.BlockManifest{Transactions: types.Transactions{}}},
		}
		ApplyInheritedMetadata(
			sourcePayload,
			meta.GetEventData(),
			meta.GetTimestamp(),
			parentAnchorBlockNumber,
			cli.L2.ChainID,
		)
		log.Info(
			"Use default derivation payload",
			"proposalID", meta.GetEventData().Id,
			"proposer", meta.GetEventData().Proposer,
			"anchorBlockNumber", parentAnchorBlockNumber,
		)
	}
}
