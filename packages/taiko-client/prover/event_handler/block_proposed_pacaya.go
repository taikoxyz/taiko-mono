package handler

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// Handle implements the BlockProposedHandler interface.
func (h *BlockProposedEventHandler) HandlePacaya(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndBlockProposedEventIterFunc,
) error {
	// If there are newly generated proofs, we need to submit them as soon as possible,
	// to avoid proof submission timeout.
	if len(h.proofGenerationCh) > 0 {
		log.Info("onBlockProposed callback early return", "proofGenerationChannelLength", len(h.proofGenerationCh))
		end()
		return nil
	}

	// Wait for the corresponding L2 block being mined in node.
	if _, err := h.rpc.WaitL2Header(
		ctx,
		new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()),
	); err != nil {
		return fmt.Errorf("failed to wait L2 header (eventID %d): %w", meta.Pacaya().GetLastBlockID(), err)
	}

	// Check if the L1 chain has reorged at first.
	if err := h.checkL1Reorg(
		ctx,
		new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()),
		meta,
	); err != nil {
		if err.Error() == errL1Reorged.Error() {
			end()
			return nil
		}

		return err
	}

	// If the current block is handled, just skip it.
	if meta.Pacaya().GetLastBlockID() <= h.sharedState.GetLastHandledBlockID() {
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
	h.sharedState.SetLastHandledBlockID(meta.Pacaya().GetLastBlockID())

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				if err := h.checkExpirationAndSubmitProofPacaya(
					ctx,
					meta,
					new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()),
				); err != nil {
					log.Error(
						"Failed to check proof status and submit proof",
						"error", err,
						"batchID", meta.Pacaya().GetBatchID(),
						"numBlobs", len(meta.Pacaya().GetBlobHashes()),
						"blocks", len(meta.Pacaya().GetBlocks()),
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

// checkExpirationAndSubmitProofPacaya checks whether the proposed batch's proving window is expired,
// and submits a new proof if necessary.
func (h *BlockProposedEventHandler) checkExpirationAndSubmitProofPacaya(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	lastBlockID *big.Int,
) error {
	// Check whether the batch has been verified.
	isVerified, err := isBlockVerified(ctx, h.rpc, lastBlockID)
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

	proofStatus, err := rpc.GetBatchProofStatus(
		ctx,
		h.rpc,
		meta.Pacaya().GetBatchID(),
	)
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

		// we need to submit a valid proof.
		h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
		return nil
	}

	windowExpired, _, timeToExpire, err := IsProvingWindowExpired(h.rpc, meta, nil)
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
			"blockOrBatchID", meta.Pacaya().GetBatchID(),
			"prover", meta.GetProposer(),
			"timeToExpire", timeToExpire,
		)

		if h.proveUnassignedBlocks {
			log.Info(
				"Add proposed block to wait for proof window expiration",
				"batchID", meta.Pacaya().GetBatchID(),
				"assignProver", meta.GetProposer(),
				"timeToExpire", timeToExpire,
			)
			time.AfterFunc(
				// Add another 72 seconds, to ensure one more L1 block will be mined before the proof submission
				timeToExpire+proofExpirationDelay,
				func() { h.assignmentExpiredCh <- meta },
			)

			return nil
		}
	}

	log.Info(
		"Proposed batch is provable",
		"batchID", meta.Pacaya().GetBatchID(),
		"assignProver", meta.GetProposer(),
	)

	metrics.ProverProofsAssigned.Add(1)

	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}

	return nil
}
