package handler

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"slices"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

var (
	errL1Reorged         = errors.New("L1 reorged")
	proofExpirationDelay = 6 * 12 * time.Second // 6 ethereum blocks
)

// BatchProposedEventHandler is responsible for handling the BatchProposed event as a prover.
type BatchProposedEventHandler struct {
	sharedState            *state.SharedState
	proverAddress          common.Address
	proverSetAddress       common.Address
	rpc                    *rpc.Client
	localProposerAddresses []common.Address
	assignmentExpiredCh    chan<- metadata.TaikoProposalMetaData
	proofSubmissionCh      chan<- *proofProducer.ProofRequestBody
	backOffRetryInterval   time.Duration
	backOffMaxRetries      uint64
	proveUnassignedBlocks  bool
}

// NewBatchProposedEventHandlerOps is the options for creating a new BatchProposedEventHandler.
type NewBatchProposedEventHandlerOps struct {
	SharedState            *state.SharedState
	ProverAddress          common.Address
	ProverSetAddress       common.Address
	RPC                    *rpc.Client
	LocalProposerAddresses []common.Address
	AssignmentExpiredCh    chan metadata.TaikoProposalMetaData
	ProofSubmissionCh      chan *proofProducer.ProofRequestBody
	BackOffRetryInterval   time.Duration
	BackOffMaxRetries      uint64
	ProveUnassignedBlocks  bool
}

// NewBatchProposedEventHandler creates a new BatchProposedEventHandler instance.
func NewBatchProposedEventHandler(opts *NewBatchProposedEventHandlerOps) *BatchProposedEventHandler {
	return &BatchProposedEventHandler{
		opts.SharedState,
		opts.ProverAddress,
		opts.ProverSetAddress,
		opts.RPC,
		opts.LocalProposerAddresses,
		opts.AssignmentExpiredCh,
		opts.ProofSubmissionCh,
		opts.BackOffRetryInterval,
		opts.BackOffMaxRetries,
		opts.ProveUnassignedBlocks,
	}
}

// Handle implements the BatchProposedHandler interface.
func (h *BatchProposedEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndBatchProposedEventIterFunc,
) error {
	// If it's a Shasta protocol event, handle it in the Shasta handler.
	if meta.IsShasta() {
		return h.HandleShasta(ctx, meta, end)
	}

	// Wait for the corresponding L2 block being mined in node.
	if _, err := h.rpc.WaitL2Header(ctx, new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID())); err != nil {
		return fmt.Errorf("failed to wait L2 header (eventID %d): %w", meta.Pacaya().GetLastBlockID(), err)
	}

	// Check if the L1 chain has reorged at first.
	if err := h.checkL1Reorg(ctx, meta.Pacaya().GetBatchID(), meta); err != nil {
		if err.Error() == errL1Reorged.Error() {
			end()
			return nil
		}

		return err
	}

	// If the current batch is handled, just skip it.
	if meta.Pacaya().GetBatchID().Uint64() <= h.sharedState.GetLastHandledPacayaBatchID() {
		return nil
	}

	log.Info(
		"New BatchProposed event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"batchID", meta.Pacaya().GetBatchID(),
		"lastBlockID", meta.Pacaya().GetLastBlockID(),
		"assignedProver", meta.GetProposer(),
		"lastTimestamp", meta.Pacaya().GetLastBlockTimestamp(),
		"numBlobs", len(meta.Pacaya().GetBlobHashes()),
		"blocks", len(meta.Pacaya().GetBlocks()),
	)

	metrics.ProverReceivedProposedBlockGauge.Set(float64(meta.Pacaya().GetLastBlockID()))

	// Move l1Current cursor.
	newL1Current, err := h.rpc.L1.HeaderByHash(ctx, meta.GetRawBlockHash())
	if err != nil {
		return err
	}
	h.sharedState.SetL1Current(newL1Current)
	h.sharedState.SetLastHandledPacayaBatchID(meta.Pacaya().GetBatchID().Uint64())

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				if err := h.checkExpirationAndSubmitProofPacaya(ctx, meta, meta.Pacaya().GetBatchID()); err != nil {
					log.Error(
						"Failed to check proof status and submit proof",
						"batchID", meta.Pacaya().GetBatchID(),
						"numBlobs", len(meta.Pacaya().GetBlobHashes()),
						"blocks", len(meta.Pacaya().GetBlocks()),
						"maxRetries", h.backOffMaxRetries,
						"error", err,
					)
					return err
				}

				return nil
			},
			backoff.WithContext(
				backoff.WithMaxRetries(backoff.NewConstantBackOff(h.backOffRetryInterval), h.backOffMaxRetries),
				ctx,
			),
		); err != nil {
			log.Error("Handle new BatchProposed event error", "error", err)
		}
	}()

	return nil
}

// checkExpirationAndSubmitProofPacaya checks whether the proposed batch's proving window is expired,
// and submits a new proof if necessary.
func (h *BatchProposedEventHandler) checkExpirationAndSubmitProofPacaya(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	batchID *big.Int,
) error {
	// Check whether the batch has been verified.
	isVerified, err := isBatchVerified(ctx, h.rpc, batchID)
	if err != nil {
		return fmt.Errorf(
			"failed to check if the current L2 batch (%d) is verified: %w",
			meta.Pacaya().GetBatchID(),
			encoding.TryParsingCustomError(err),
		)
	}
	if isVerified {
		log.Info("📋 Batch has been verified", "batchID", meta.Pacaya().GetBatchID())
		return nil
	}

	proofStatus, err := rpc.GetBatchProofStatus(ctx, h.rpc, meta.Pacaya().GetBatchID())
	if err != nil {
		return fmt.Errorf("failed to check whether the L2 batch needs a new proof: %w", err)
	}

	// If there is already a proof submitted on chain.
	if proofStatus.IsSubmitted {
		// If there is a valid proof already, we skip proving this block here.
		if !proofStatus.Invalid {
			log.Info(
				"A valid proof has been submitted, skip proving",
				"batchID", meta.Pacaya().GetBatchID(),
				"parent", proofStatus.ParentHeader.Hash(),
			)
			return nil
		}

		// We need to submit a valid proof.
		h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
		return nil
	}

	windowExpired, _, timeToExpire, err := IsProvingWindowExpired(h.rpc, meta)
	if err != nil {
		return fmt.Errorf("failed to check if the proving window is expired: %w", err)
	}

	// If the proving window is not expired, we need to check if the current prover is the assigned prover,
	// if no and the current prover wants to prove unassigned blocks, then we should wait for its expiration.
	if !windowExpired && !h.shouldProve(meta.GetProposer()) {
		log.Info(
			"Proposed batch is not provable by current prover at the moment",
			"batchID", meta.Pacaya().GetBatchID(),
			"prover", meta.GetProposer(),
			"timeToExpire", timeToExpire,
			"localProposerAddresses", h.localProposerAddresses,
		)

		if h.proveUnassignedBlocks {
			log.Info(
				"Add proposed block to wait for proof window expiration",
				"batchID", meta.Pacaya().GetBatchID(),
				"assignProver", meta.GetProposer(),
				"timeToExpire", timeToExpire,
				"localProposerAddresses", h.localProposerAddresses,
			)
			time.AfterFunc(
				// Add another 72 seconds, to ensure one more L1 block will be mined before the proof submission
				timeToExpire+proofExpirationDelay,
				func() { h.assignmentExpiredCh <- meta },
			)

			return nil
		}
	}

	// If the current prover is not the assigned prover, and `--prover.proveUnassignedBlocks` is not set,
	// we should skip proving this batch.
	if !h.proveUnassignedBlocks && !h.shouldProve(meta.GetProposer()) {
		log.Info(
			"Expired batch is not provable by current prover",
			"batchID", meta.Pacaya().GetBatchID(),
			"currentProver", h.proverAddress,
			"currentProverSet", h.proverSetAddress,
			"assignProver", meta.GetProposer(),
			"localProposerAddresses", h.localProposerAddresses,
		)
		return nil
	}

	log.Info(
		"Proposed batch is provable",
		"batchID", meta.Pacaya().GetBatchID(),
		"assignProver", meta.GetProposer(),
		"localProposerAddresses", h.localProposerAddresses,
	)

	metrics.ProverProofsAssigned.Add(1)

	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}

	return nil
}

// checkL1Reorg checks whether the L1 chain has been reorged.
func (h *BatchProposedEventHandler) checkL1Reorg(
	ctx context.Context,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
) error {
	log.Debug("Check L1 reorg", "batchID", batchID)

	// Ensure the L1 header in canonical chain is the same as the one in the event.
	l1Header, err := h.rpc.L1.HeaderByNumber(ctx, meta.GetRawBlockHeight())
	if err != nil {
		return fmt.Errorf("failed to get L1 header, height %d: %w", meta.GetRawBlockHeight(), err)
	}
	if l1Header.Hash() != meta.GetRawBlockHash() {
		log.Warn(
			"L1 block hash mismatch, will retry",
			"height", meta.GetRawBlockHeight(),
			"l1HashInChain", l1Header.Hash(),
			"l1HashInEvent", meta.GetRawBlockHash(),
		)
		return fmt.Errorf("L1 block hash mismatch: %s != %s", l1Header.Hash(), meta.GetRawBlockHash())
	}

	// Check whether the L2 EE's anchored L1 info, to see if the L1 chain has been reorged.
	reorgCheckResult, err := h.rpc.CheckL1Reorg(ctx, new(big.Int).Sub(batchID, common.Big1), meta.IsShasta())
	if err != nil {
		return fmt.Errorf("failed to check whether L1 chain was reorged from L2EE (batchID %d): %w", batchID, err)
	}

	if reorgCheckResult.IsReorged {
		lastHandledOld := h.sharedState.GetLastHandledPacayaBatchID()
		if meta.IsShasta() {
			lastHandledOld = h.sharedState.GetLastHandledShastaBatchID()
		}

		log.Info(
			"Reset L1Current cursor due to reorg",
			"l1CurrentHeightOld", h.sharedState.GetL1Current().Number,
			"l1CurrentHeightNew", reorgCheckResult.L1CurrentToReset.Number,
			"lastHandledBatchIDOld", lastHandledOld,
			"lastHandledBatchIDNew", reorgCheckResult.LastHandledBatchIDToReset,
		)
		h.sharedState.SetL1Current(reorgCheckResult.L1CurrentToReset)
		if meta.IsShasta() {
			if reorgCheckResult.LastHandledBatchIDToReset == nil {
				h.sharedState.SetLastHandledShastaBatchID(0)
			} else {
				h.sharedState.SetLastHandledShastaBatchID(reorgCheckResult.LastHandledBatchIDToReset.Uint64())
			}
		} else {
			if reorgCheckResult.LastHandledBatchIDToReset == nil {
				h.sharedState.SetLastHandledPacayaBatchID(0)
			} else {
				h.sharedState.SetLastHandledPacayaBatchID(reorgCheckResult.LastHandledBatchIDToReset.Uint64())
			}
		}
		return errL1Reorged
	}

	return nil
}

// shouldProve checks whether the current running prover is assigned to prove the proposed batch.
func (h *BatchProposedEventHandler) shouldProve(assignedProver common.Address) bool {
	return assignedProver == h.proverAddress ||
		assignedProver == h.proverSetAddress ||
		slices.Contains(h.localProposerAddresses, assignedProver)
}
