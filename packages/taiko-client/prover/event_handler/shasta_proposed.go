package handler

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
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
	if meta.Shasta().GetEventData().Id.Cmp(common.Big0) == 0 {
		return nil
	}

	// Wait for the corresponding L2 block being mined in node.
	header, err := h.rpc.WaitShastaHeader(ctx, meta.Shasta().GetEventData().Id)
	if err != nil {
		return fmt.Errorf("failed to wait L2 Shasta header (batchID %d): %w", meta.Shasta().GetEventData().Id, err)
	}

	// Check if the L1 chain has reorged at first.
	if err := h.checkL1Reorg(ctx, meta.Shasta().GetEventData().Id, meta); err != nil {
		if err.Error() == errL1Reorged.Error() {
			end()
			return nil
		}

		return err
	}

	// If the current batch is handled, just skip it.
	if meta.Shasta().GetEventData().Id.Uint64() <= h.sharedState.GetLastHandledShastaBatchID() {
		return nil
	}

	log.Info(
		"New Shasta Proposed event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"batchID", meta.Shasta().GetEventData().Id,
		"lastBlockID", header.Number,
		"proposer", meta.GetProposer(),
		"proposalTimestamp", meta.Shasta().GetTimestamp(),
		"derivationSources", len(meta.Shasta().GetEventData().Sources),
	)

	metrics.ProverReceivedProposedBlockGauge.Set(float64(meta.Shasta().GetEventData().Id.Uint64()))

	// Move l1Current cursor.
	newL1Current, err := h.rpc.L1.HeaderByHash(ctx, meta.GetRawBlockHash())
	if err != nil {
		return err
	}
	h.sharedState.SetL1Current(newL1Current)
	h.sharedState.SetLastHandledShastaBatchID(meta.Shasta().GetEventData().Id.Uint64())

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				if err := h.checkExpirationAndSubmitProofShasta(
					ctx,
					meta,
					meta.Shasta().GetEventData().Id,
					meta.GetProposer(),
				); err != nil {
					log.Error(
						"Failed to check Shasta proof status and submit proof",
						"batchID", meta.Shasta().GetEventData().Id,
						"derivationSources", len(meta.Shasta().GetEventData().Sources),
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
	designatedProver common.Address,
) error {
	coreState, err := h.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta core state: %w", err)
	}

	if batchID.Cmp(coreState.LastFinalizedProposalId) <= 0 {
		log.Info(
			"📋 Shasta batch has been verified",
			"batchID", batchID,
			"lastFinalizedProposalId", coreState.LastFinalizedProposalId,
		)
		return nil
	}

	windowExpired, _, timeToExpire, err := IsProvingWindowExpiredShasta(h.rpc, meta)
	if err != nil {
		return fmt.Errorf("failed to check if the proving window is expired: %w", err)
	}

	// If the proving window is not expired, we need to check if the current prover is the assigned prover,
	// if no and the current prover wants to prove unassigned blocks, then we should wait for its expiration.
	if !windowExpired && !h.shouldProve(designatedProver) {
		log.Info(
			"Proposed Shasta batch is not provable by current prover at the moment",
			"batchID", meta.Shasta().GetEventData().Id,
			"designatedProver", designatedProver,
			"timeToExpire", timeToExpire,
			"localProposerAddresses", h.localProposerAddresses,
		)

		if h.proveUnassignedBlocks {
			log.Info(
				"Add proposed Shasta batch to wait for proof window expiration",
				"batchID", meta.Shasta().GetEventData().Id,
				"designatedProver", designatedProver,
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
	if !h.proveUnassignedBlocks && !h.shouldProve(designatedProver) {
		log.Info(
			"Expired Shasta batch is not provable by current prover",
			"batchID", meta.Shasta().GetEventData().Id,
			"currentProver", h.proverAddress,
			"currentProverSet", h.proverSetAddress,
			"designatedProver", designatedProver,
			"localProposerAddresses", h.localProposerAddresses,
		)
		return nil
	}

	log.Info(
		"Proposed Shasta batch is provable",
		"batchID", meta.Shasta().GetEventData().Id,
		"designatedProver", designatedProver,
		"localProposerAddresses", h.localProposerAddresses,
	)

	metrics.ProverProofsAssigned.Add(1)

	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}

	return nil
}
