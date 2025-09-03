package event

import (
	"context"
	"errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// checkBlockLevelMetadata validates and adjusts block-level metadata according to protocol rules
func checkBlockLevelMetadata(
	ctx context.Context,
	rpc *rpc.Client,
	proposalManifest *manifest.ProposalManifest,
	isForcedInclusion bool,
	proposal shastaBindings.IInboxProposal,
	parentBlock *types.Block,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
) error {
	if proposalManifest == nil {
		return errors.New("non-point proposal manifest")
	}
	// If there is the default manifest, we return directly
	if proposalManifest.IsDefault {
		return nil
	}

	if len(proposalManifest.Blocks) == 0 {
		return errors.New("invalid proposal manifest: no blocks")
	}

	// Track if any block has a valid anchor number for forced inclusion protection
	var (
		hasValidAnchor  = false
		parentTimestamp = parentBlock.Time()
		parentGasLimit  = parentBlock.GasLimit()
	)

	for i := range proposalManifest.Blocks {
		// Timestamp Validation
		if proposalManifest.Blocks[i].Timestamp > proposal.Timestamp.Uint64() {
			log.Debug("Adjusting block timestamp to proposal timestamp",
				"blockIndex", i,
				"originalTimestamp", proposalManifest.Blocks[i].Timestamp,
				"newTimestamp", proposal.Timestamp)
			proposalManifest.Blocks[i].Timestamp = proposal.Timestamp.Uint64()
		}

		// Calculate lower bound for timestamp
		lowerBound := parentTimestamp + 1
		if proposal.Timestamp.Uint64() > manifest.TimestampMaxOffset {
			timestampLowerBound := proposal.Timestamp.Uint64() - manifest.TimestampMaxOffset
			if timestampLowerBound > lowerBound {
				lowerBound = timestampLowerBound
			}
		}

		if proposalManifest.Blocks[i].Timestamp < lowerBound {
			log.Debug("Adjusting block timestamp to lower bound",
				"blockIndex", i,
				"originalTimestamp", proposalManifest.Blocks[i].Timestamp,
				"newTimestamp", lowerBound)
			proposalManifest.Blocks[i].Timestamp = lowerBound
		}

		// Anchor Block Number Validation
		isInvalidAnchor := false

		// Check non-monotonic progression
		if proposalManifest.Blocks[i].AnchorBlockNumber < parentAnchorBlockNumber {
			log.Debug("Invalid anchor: non-monotonic progression",
				"blockIndex", i,
				"anchorBlockNumber", proposalManifest.Blocks[i].AnchorBlockNumber,
				"parentAnchorBlockNumber", parentAnchorBlockNumber)
			isInvalidAnchor = true
		}

		// Check future reference
		if proposalManifest.Blocks[i].AnchorBlockNumber >= originBlockNumber-manifest.AnchorMinOffset {
			log.Debug("Invalid anchor: future reference",
				"blockIndex", i,
				"anchorBlockNumber", proposalManifest.Blocks[i].AnchorBlockNumber,
				"originBlockNumber", originBlockNumber)
			isInvalidAnchor = true
		}

		// Check excessive lag
		if originBlockNumber > manifest.AnchorMaxOffset && proposalManifest.Blocks[i].AnchorBlockNumber < originBlockNumber-manifest.AnchorMaxOffset {
			log.Debug("Invalid anchor: excessive lag",
				"blockIndex", i,
				"anchorBlockNumber", proposalManifest.Blocks[i].AnchorBlockNumber,
				"minRequired", originBlockNumber-manifest.AnchorMaxOffset)
			isInvalidAnchor = true
		}

		if isInvalidAnchor {
			log.Info("Setting anchor block number to parent's anchor",
				"blockIndex", i,
				"originalAnchor", proposalManifest.Blocks[i].AnchorBlockNumber,
				"newAnchor", parentAnchorBlockNumber)
			proposalManifest.Blocks[i].AnchorBlockNumber = parentAnchorBlockNumber
		} else if proposalManifest.Blocks[i].AnchorBlockNumber > parentAnchorBlockNumber {
			hasValidAnchor = true
		}

		// Coinbase Assignment
		if isForcedInclusion {
			// Forced inclusions always use proposal.proposer
			proposalManifest.Blocks[i].Coinbase = proposal.Proposer
		} else if (proposalManifest.Blocks[i].Coinbase == common.Address{}) {
			// Use proposal.proposer as fallback if manifest coinbase is zero
			proposalManifest.Blocks[i].Coinbase = proposal.Proposer
		}
		// Otherwise keep the manifest's coinbase

		// Gas Limit Validation
		// Calculate bounds
		lowerGasBound := parentGasLimit * (10000 - manifest.MaxBlockGasLimitChangePermyriad) / 10000
		if lowerGasBound < manifest.MinBlockGasLimit {
			lowerGasBound = manifest.MinBlockGasLimit
		}
		upperGasBound := parentGasLimit * (10000 + manifest.MaxBlockGasLimitChangePermyriad) / 10000

		// Apply constraints
		if proposalManifest.Blocks[i].GasLimit == 0 {
			// Inherit parent value
			proposalManifest.Blocks[i].GasLimit = parentGasLimit
		} else if proposalManifest.Blocks[i].GasLimit < lowerGasBound {
			log.Debug("Clamping gas limit to lower bound",
				"blockIndex", i,
				"originalGasLimit", proposalManifest.Blocks[i].GasLimit,
				"newGasLimit", lowerGasBound)
			proposalManifest.Blocks[i].GasLimit = lowerGasBound
		} else if proposalManifest.Blocks[i].GasLimit > upperGasBound {
			log.Debug("Clamping gas limit to upper bound",
				"blockIndex", i,
				"originalGasLimit", proposalManifest.Blocks[i].GasLimit,
				"newGasLimit", upperGasBound)
			proposalManifest.Blocks[i].GasLimit = upperGasBound
		}

		// Update parent values for next iteration
		if i < len(proposalManifest.Blocks)-1 {
			// Update parent timestamp for next block
			parentTimestamp = proposalManifest.Blocks[i].Timestamp
			// Update parent gas limit for next block
			parentGasLimit = proposalManifest.Blocks[i].GasLimit
			// Update parent anchor if it changed
			if proposalManifest.Blocks[i].AnchorBlockNumber > parentAnchorBlockNumber {
				parentAnchorBlockNumber = proposalManifest.Blocks[i].AnchorBlockNumber
			}
		}
	}

	// Forced inclusion protection
	if !isForcedInclusion && !hasValidAnchor {
		log.Warn("Non-forced proposal has no valid anchor blocks, replacing with default manifest")
		// Replace the entire manifest with the default manifest
		// This penalizes proposals that fail to provide proper L1 anchoring
		proposalManifest.IsDefault = true
		return nil
	}

	// TODO: bondInstructionsHash and bondInstructions validation would be handled
	// in the calling code as it requires fetching L1 state and events

	return nil
}
