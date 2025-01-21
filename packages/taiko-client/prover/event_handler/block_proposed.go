package handler

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	guardianProverHeartbeater "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/guardian_prover_heartbeater"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

var (
	errL1Reorged         = errors.New("L1 reorged")
	proofExpirationDelay = 6 * 12 * time.Second // 6 ethereum blocks
)

// BlockProposedEventHandler is responsible for handling the BlockProposed event as a prover.
type BlockProposedEventHandler struct {
	sharedState           *state.SharedState
	proverAddress         common.Address
	proverSetAddress      common.Address
	rpc                   *rpc.Client
	proofGenerationCh     chan<- *proofProducer.ProofWithHeader
	assignmentExpiredCh   chan<- metadata.TaikoProposalMetaData
	proofSubmissionCh     chan<- *proofProducer.ProofRequestBody
	proofContestCh        chan<- *proofProducer.ContestRequestBody
	backOffRetryInterval  time.Duration
	backOffMaxRetrys      uint64
	contesterMode         bool
	proveUnassignedBlocks bool
	// Guardian prover related.
	isGuardian bool
}

// NewBlockProposedEventHandlerOps is the options for creating a new BlockProposedEventHandler.
type NewBlockProposedEventHandlerOps struct {
	SharedState           *state.SharedState
	ProverAddress         common.Address
	ProverSetAddress      common.Address
	RPC                   *rpc.Client
	ProofGenerationCh     chan *proofProducer.ProofWithHeader
	AssignmentExpiredCh   chan metadata.TaikoProposalMetaData
	ProofSubmissionCh     chan *proofProducer.ProofRequestBody
	ProofContestCh        chan *proofProducer.ContestRequestBody
	BackOffRetryInterval  time.Duration
	BackOffMaxRetrys      uint64
	ContesterMode         bool
	ProveUnassignedBlocks bool
}

// NewBlockProposedEventHandler creates a new BlockProposedEventHandler instance.
func NewBlockProposedEventHandler(opts *NewBlockProposedEventHandlerOps) *BlockProposedEventHandler {
	return &BlockProposedEventHandler{
		opts.SharedState,
		opts.ProverAddress,
		opts.ProverSetAddress,
		opts.RPC,
		opts.ProofGenerationCh,
		opts.AssignmentExpiredCh,
		opts.ProofSubmissionCh,
		opts.ProofContestCh,
		opts.BackOffRetryInterval,
		opts.BackOffMaxRetrys,
		opts.ContesterMode,
		opts.ProveUnassignedBlocks,
		false,
	}
}

// Handle implements the BlockProposedHandler interface.
func (h *BlockProposedEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndBlockProposedEventIterFunc,
) error {
	if meta.IsPacaya() {
		return h.HandlePacaya(ctx, meta, end)
	}
	// If there are newly generated proofs, we need to submit them as soon as possible,
	// to avoid proof submission timeout.
	if len(h.proofGenerationCh) > 0 {
		log.Info("onBlockProposed callback early return", "proofGenerationChannelLength", len(h.proofGenerationCh))
		end()
		return nil
	}

	batch, err := h.rpc.GetBatchByID(ctx, meta.TaikoBatchMetaDataPacaya().GetBatchID())
	if err != nil {
		return fmt.Errorf("failed to get batch by ID: %w", err)
	}
	blockID := new(big.Int).SetUint64(batch.LastBlockId)

	// Wait for the corresponding L2 block being mined in node.
	if _, err := h.rpc.WaitL2Header(ctx, blockID); err != nil {
		return fmt.Errorf("failed to wait L2 header (eventID %d): %w", blockID, err)
	}

	// Check if the L1 chain has reorged at first.
	if err := h.checkL1Reorg(ctx, blockID, meta); err != nil {
		if err.Error() == errL1Reorged.Error() {
			end()
			return nil
		}

		return err
	}

	// If the current block is handled, just skip it.
	if blockID.Uint64() <= h.sharedState.GetLastHandledBlockID() {
		return nil
	}

	log.Info(
		"New BlockProposedV2 event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
		"assignedProver", meta.GetProposer(),
		"blobHash", meta.TaikoBlockMetaDataOntake().GetBlobHash(),
		"livenessBond", utils.WeiToEther(meta.TaikoBlockMetaDataOntake().GetLivenessBond()),
		"minTier", meta.TaikoBlockMetaDataOntake().GetMinTier(),
		"blobUsed", meta.TaikoBlockMetaDataOntake().GetBlobUsed(),
	)

	metrics.ProverReceivedProposedBlockGauge.Set(float64(blockID.Uint64()))

	// Move l1Current cursor.
	newL1Current, err := h.rpc.L1.HeaderByHash(ctx, meta.GetRawBlockHash())
	if err != nil {
		return err
	}
	h.sharedState.SetL1Current(newL1Current)
	h.sharedState.SetLastHandledBlockID(blockID.Uint64())

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				if err := h.checkExpirationAndSubmitProofOntake(ctx, meta); err != nil {
					log.Error(
						"Failed to check proof status and submit proof",
						"error", err,
						"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
						"minTier", meta.TaikoBlockMetaDataOntake().GetMinTier(),
						"maxRetrys", h.backOffMaxRetrys,
					)
					return err
				}
				return nil
			},
			backoff.WithContext(
				backoff.WithMaxRetries(backoff.NewConstantBackOff(h.backOffRetryInterval), h.backOffMaxRetrys),
				ctx,
			),
		); err != nil {
			log.Error("Handle new BlockProposed event error", "error", err)
		}
	}()

	return nil
}

// checkL1Reorg checks whether the L1 chain has been reorged.
func (h *BlockProposedEventHandler) checkL1Reorg(
	ctx context.Context,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
) error {
	// Check whether the L2 EE's anchored L1 info, to see if the L1 chain has been reorged.
	reorgCheckResult, err := h.rpc.CheckL1Reorg(
		ctx,
		new(big.Int).Sub(blockID, common.Big1),
	)
	if err != nil {
		return fmt.Errorf(
			"failed to check whether L1 chain was reorged from L2EE (eventID %d): %w",
			blockID,
			err,
		)
	}

	if reorgCheckResult.IsReorged {
		log.Info(
			"Reset L1Current cursor due to reorg",
			"l1CurrentHeightOld", h.sharedState.GetL1Current().Number,
			"l1CurrentHeightNew", reorgCheckResult.L1CurrentToReset.Number,
			"lastHandledBlockIDOld", h.sharedState.GetLastHandledBlockID(),
			"lastHandledBlockIDNew", reorgCheckResult.LastHandledBlockIDToReset,
		)
		h.sharedState.SetL1Current(reorgCheckResult.L1CurrentToReset)
		if reorgCheckResult.LastHandledBlockIDToReset == nil {
			h.sharedState.SetLastHandledBlockID(0)
		} else {
			h.sharedState.SetLastHandledBlockID(reorgCheckResult.LastHandledBlockIDToReset.Uint64())
		}
		return errL1Reorged
	}

	lastL1OriginHeader, err := h.rpc.L1.HeaderByNumber(ctx, meta.GetRawBlockHeight())
	if err != nil {
		return fmt.Errorf(
			"failed to get L1 header, height %d: %w",
			meta.GetRawBlockHeight(),
			err,
		)
	}

	if lastL1OriginHeader.Hash() != meta.GetRawBlockHash() {
		log.Warn(
			"L1 block hash mismatch due to L1 reorg",
			"height", meta.GetRawBlockHeight(),
			"lastL1OriginHeader", lastL1OriginHeader.Hash(),
			"l1HashInEvent", meta.GetRawBlockHash(),
		)

		return fmt.Errorf(
			"L1 block hash mismatch due to L1 reorg: %s != %s",
			lastL1OriginHeader.Hash(),
			meta.GetRawBlockHash(),
		)
	}

	return nil
}

// checkExpirationAndSubmitProofOntake checks whether the proposed block's proving window is expired,
// and submits a new proof if necessary.
func (h *BlockProposedEventHandler) checkExpirationAndSubmitProofOntake(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
) error {
	// Check whether the block has been verified.
	isVerified, err := isBlockVerified(ctx, h.rpc, meta.TaikoBlockMetaDataOntake().GetBlockID())
	if err != nil {
		return fmt.Errorf("failed to check if the current L2 block is verified: %w", err)
	}
	if isVerified {
		log.Info("📋 Block has been verified", "blockID", meta.TaikoBlockMetaDataOntake().GetBlockID())
		return nil
	}

	proofStatus, err := rpc.GetBlockProofStatus(
		ctx,
		h.rpc,
		meta.TaikoBlockMetaDataOntake().GetBlockID(),
		h.proverAddress,
		h.proverSetAddress,
	)
	if err != nil {
		return fmt.Errorf("failed to check whether the L2 block needs a new proof: %w", err)
	}

	// If there is already a proof submitted on chain.
	if proofStatus.IsSubmitted {
		// If there is no need to contest the submitted proof, we skip proving this block here.
		if !proofStatus.Invalid {
			log.Info(
				"A valid proof has been submitted, skip proving",
				"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
				"parent", proofStatus.ParentHeader.Hash(),
			)
			return nil
		}

		// If there is an invalid proof, but current prover is not in contest mode, we skip proving this block.
		if !h.contesterMode {
			log.Info(
				"An invalid proof has been submitted, but current prover is not in contest mode, skip proving",
				"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
				"parent", proofStatus.ParentHeader.Hash(),
			)
			return nil
		}

		if h.isGuardian {
			// In guardian prover, we submit a proof directly.
			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Tier: encoding.TierGuardianMinorityID, Meta: meta}
		} else {
			// If the current proof has not been contested, we should contest it at first.
			if proofStatus.CurrentTransitionState.Contester == rpc.ZeroAddress {
				h.proofContestCh <- &proofProducer.ContestRequestBody{
					BlockID:    meta.TaikoBlockMetaDataOntake().GetBlockID(),
					ProposedIn: meta.TaikoBlockMetaDataOntake().GetRawBlockHeight(),
					ParentHash: proofStatus.ParentHeader.Hash(),
					Meta:       meta,
					Tier:       meta.TaikoBlockMetaDataOntake().GetMinTier(),
				}
			} else {
				// The invalid proof submitted to protocol is contested by another prover,
				// we need to submit a proof with a higher tier.
				h.proofSubmissionCh <- &proofProducer.ProofRequestBody{
					Tier: proofStatus.CurrentTransitionState.Tier + 1,
					Meta: meta,
				}
			}
		}

		return nil
	}

	windowExpired, _, timeToExpire, err := IsProvingWindowExpired(h.rpc, meta, h.sharedState.GetTiers())
	if err != nil {
		return fmt.Errorf("failed to check if the proving window is expired: %w", err)
	}

	// If the proving window is not expired, we need to check if the current prover is the assigned prover,
	// if no and the current prover wants to prove unassigned blocks, then we should wait for its expiration.
	if !windowExpired &&
		meta.GetProposer() != h.proverAddress &&
		meta.GetProposer() != h.proverSetAddress {
		log.Info(
			"Proposed batch is not provable by current prover at the moment",
			"blockOrBatchID", meta.TaikoBatchMetaDataPacaya().GetBatchID(),
			"prover", meta.GetProposer(),
			"timeToExpire", timeToExpire,
		)

		if h.proveUnassignedBlocks {
			log.Info(
				"Add proposed block to wait for proof window expiration",
				"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
				"assignProver", meta.TaikoBlockMetaDataOntake().GetAssignedProver(),
				"timeToExpire", timeToExpire,
			)
			time.AfterFunc(
				// Add another 72 seconds, to ensure one more L1 block will be mined before the proof submission
				timeToExpire+proofExpirationDelay,
				func() { h.assignmentExpiredCh <- meta },
			)
		}

		return nil
	}

	// The current prover is the assigned prover, or the proving window is expired,
	// try to submit a proof for this proposed block.
	tier := meta.TaikoBlockMetaDataOntake().GetMinTier()

	if h.isGuardian {
		tier = encoding.TierGuardianMinorityID
	}

	log.Info(
		"Proposed block is provable",
		"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
		"assignProver", meta.TaikoBlockMetaDataOntake().GetAssignedProver(),
		"minTier", meta.TaikoBlockMetaDataOntake().GetMinTier(),
		"tier", tier,
	)

	metrics.ProverProofsAssigned.Add(1)

	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Tier: tier, Meta: meta}

	return nil
}

// ========================= Guardian Prover =========================

// NewBlockProposedGuardianEventHandlerOps is the options for creating a new BlockProposedEventHandler.
type NewBlockProposedGuardianEventHandlerOps struct {
	*NewBlockProposedEventHandlerOps
	GuardianProverHeartbeater guardianProverHeartbeater.BlockSenderHeartbeater
}

// BlockProposedGuaridanEventHandler is responsible for handling the BlockProposed event as a guardian prover.
type BlockProposedGuaridanEventHandler struct {
	*BlockProposedEventHandler
	GuardianProverHeartbeater guardianProverHeartbeater.BlockSenderHeartbeater
}

// NewBlockProposedEventGuardianHandler creates a new BlockProposedEventHandler instance.
func NewBlockProposedEventGuardianHandler(
	opts *NewBlockProposedGuardianEventHandlerOps,
) *BlockProposedGuaridanEventHandler {
	blockProposedEventHandler := NewBlockProposedEventHandler(opts.NewBlockProposedEventHandlerOps)
	blockProposedEventHandler.isGuardian = true

	return &BlockProposedGuaridanEventHandler{
		BlockProposedEventHandler: blockProposedEventHandler,
		GuardianProverHeartbeater: opts.GuardianProverHeartbeater,
	}
}

// Handle implements the BlockProposedHandler interface.
func (h *BlockProposedGuaridanEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndBlockProposedEventIterFunc,
) error {
	// If we are operating as a guardian prover,
	// we should sign all seen proposed blocks as soon as possible.
	go func() {
		if h.GuardianProverHeartbeater == nil {
			return
		}
		if err := h.GuardianProverHeartbeater.SignAndSendBlock(
			ctx, meta.TaikoBlockMetaDataOntake().GetBlockID(),
		); err != nil {
			log.Error(
				"Guardian prover unable to sign block",
				"blockID", meta.TaikoBlockMetaDataOntake().GetBlockID(),
				"error", err,
			)
		}
	}()

	return h.BlockProposedEventHandler.Handle(ctx, meta, end)
}
