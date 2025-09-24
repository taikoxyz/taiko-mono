package handler

import (
	"context"
	"fmt"
	"math/big"
	"slices"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

// HandleShasta handles the Shasta protocol Proposed event.
func (h *BatchProposedEventHandler) HandleShasta(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndBatchProposedEventIterFunc,
) error {
	if !meta.IsShasta() {
		log.Debug("Skip non-Shasta Proposed event", "batchID", meta.Pacaya().GetBatchID())
		return nil
	}
	if meta.Shasta().GetProposal().Id.Cmp(common.Big0) == 0 {
		return nil
	}

	// Wait for the corresponding L2 block being mined in node.
	header, err := h.rpc.WaitShastaHeader(ctx, meta.Shasta().GetProposal().Id)
	if err != nil {
		return fmt.Errorf("failed to wait L2 Shasta header (batchID %d): %w", meta.Shasta().GetProposal().Id, err)
	}

	// Check if the L1 chain has reorged at first.
	if err := h.checkL1Reorg(ctx, meta.Shasta().GetProposal().Id, meta); err != nil {
		if err.Error() == errL1Reorged.Error() {
			end()
			return nil
		}

		return err
	}

	// If the current batch is handled, just skip it.
	if meta.Shasta().GetProposal().Id.Uint64() <= h.sharedState.GetLastHandledShastaBatchID() {
		return nil
	}

	log.Info(
		"New Shasta Proposed event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"batchID", meta.Shasta().GetProposal().Id,
		"lastBlockID", header.Number,
		"assignedProver", meta.GetProposer(),
		"proposalTimestamp", meta.Shasta().GetProposal().Timestamp,
		"numBlobs", len(meta.Shasta().GetBlobHashes()),
	)

	metrics.ProverReceivedProposedBlockGauge.Set(float64(meta.Shasta().GetProposal().Id.Uint64()))

	// Move l1Current cursor.
	newL1Current, err := h.rpc.L1.HeaderByHash(ctx, meta.GetRawBlockHash())
	if err != nil {
		return err
	}
	h.sharedState.SetL1Current(newL1Current)
	h.sharedState.SetLastHandledShastaBatchID(meta.Shasta().GetProposal().Id.Uint64())

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				if err := h.checkExpirationAndSubmitProofShasta(ctx, meta, meta.Shasta().GetProposal().Id); err != nil {
					log.Error(
						"Failed to check Shasta proof status and submit proof",
						"batchID", meta.Shasta().GetProposal().Id,
						"numBlobs", len(meta.Shasta().GetBlobHashes()),
						"maxRetrys", h.backOffMaxRetrys,
						"error", err,
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
			log.Error("Handle new Shasta Proposed event error", "error", err)
		}
	}()

	return nil
}

// checkExpirationAndSubmitProofShasta checks whether the proposed batch's proving window is expired,
// and submits a new proof if necessary.
func (h *BatchProposedEventHandler) checkExpirationAndSubmitProofShasta(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	batchID *big.Int,
) error {
	// Check whether the batch has been verified.
	var (
		coreState = h.indexer.GetLastCoreState()
		record    = h.indexer.GetTransitionRecordByProposalID(batchID.Uint64())
	)
	if coreState == nil {
		return fmt.Errorf("core state is nil")
	}

	if batchID.Cmp(coreState.LastFinalizedProposalId) <= 0 {
		log.Info(
			"📋 Shasta batch has been verified",
			"batchID", batchID,
			"lastFinalizedProposalId", coreState.LastFinalizedProposalId,
		)
		return nil
	}

	if record != nil {
		header, err := h.rpc.L2.HeaderByNumber(ctx, record.Transition.Checkpoint.BlockNumber)
		if err != nil {
			return fmt.Errorf("failed to get L2 header by number: %w", err)
		}

		proposalHash, err := h.rpc.GetShastaProposalHash(&bind.CallOpts{Context: ctx}, batchID)
		if err != nil {
			return fmt.Errorf("failed to get Shasta proposal hash: %w", err)
		}
		parentTransitionHash, err := transaction.BuildParentTransitionHash(ctx, h.rpc, h.indexer, batchID)
		if err != nil {
			return fmt.Errorf("failed to build parent Shasta transition hash: %w", err)
		}

		if record.Transition.Checkpoint.BlockHash == header.Hash() &&
			record.Transition.ParentTransitionHash == parentTransitionHash &&
			record.Transition.ProposalHash == proposalHash {
			log.Info(
				"A valid proof has been submitted, skip proving",
				"batchID", batchID,
				"parentBlockHash", header.ParentHash,
				"parentTransitionHash", parentTransitionHash,
				"proposalHash", common.BytesToHash(record.Transition.ProposalHash[:]),
			)
			return nil
		}

		log.Warn(
			"Invalid Shasta proof onchain, submitting a new proof",
			"batchID", batchID,
			"parentBlockHash", header.ParentHash,
			"parentTransitionHash", parentTransitionHash,
			"proposalHash", common.BytesToHash(record.Transition.ProposalHash[:]),
		)
		// We need to submit a valid proof.
		h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
		return nil
	}

	windowExpired, _, timeToExpire, err := IsProvingWindowExpiredShasta(h.rpc, meta)
	if err != nil {
		return fmt.Errorf("failed to check if the proving window is expired: %w", err)
	}

	// If the proving window is not expired, we need to check if the current prover is the assigned prover,
	// if no and the current prover wants to prove unassigned blocks, then we should wait for its expiration.
	if !windowExpired &&
		meta.GetProposer() != h.proverAddress &&
		meta.GetProposer() != h.proverSetAddress &&
		!slices.Contains(h.localProposerAddresses, meta.GetProposer()) {
		log.Info(
			"Proposed Shasta batch is not provable by current prover at the moment",
			"batchID", meta.Shasta().GetProposal().Id,
			"prover", meta.GetProposer(),
			"timeToExpire", timeToExpire,
			"localProposerAddresses", h.localProposerAddresses,
		)

		if h.proveUnassignedBlocks {
			log.Info(
				"Add proposed Shasta batch to wait for proof window expiration",
				"batchID", meta.Shasta().GetProposal().Id,
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
	if !h.proveUnassignedBlocks &&
		meta.GetProposer() != h.proverAddress &&
		meta.GetProposer() != h.proverSetAddress &&
		!slices.Contains(h.localProposerAddresses, meta.GetProposer()) {
		log.Info(
			"Expired Shasta batch is not provable by current prover",
			"batchID", meta.Shasta().GetProposal().Id,
			"currentProver", h.proverAddress,
			"currentProverSet", h.proverSetAddress,
			"assignProver", meta.GetProposer(),
			"localProposerAddresses", h.localProposerAddresses,
		)
		return nil
	}

	log.Info(
		"Proposed Shasta batch is provable",
		"batchID", meta.Shasta().GetProposal().Id,
		"assignProver", meta.GetProposer(),
		"localProposerAddresses", h.localProposerAddresses,
	)

	metrics.ProverProofsAssigned.Add(1)

	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}

	return nil
}
