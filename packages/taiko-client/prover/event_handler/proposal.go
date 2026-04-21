package handler

import (
	"context"
	"errors"
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

// handleProposal handles the protocol Proposed event.
func (h *ProposalEventHandler) handleProposal(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndProposalEventIterFunc,
) error {
	if !meta.IsShasta() {
		log.Debug("Skip non-proposal event")
		return nil
	}

	event := meta.Shasta().GetEventData()
	proposalID := event.Id

	if proposalID.Cmp(common.Big0) == 0 {
		return nil
	}

	// Wait for the corresponding L2 block being mined in node.
	header, err := h.rpc.WaitProposalHeader(ctx, proposalID)
	if err != nil {
		return fmt.Errorf("failed to wait L2 header (proposalID %d): %w", proposalID, err)
	}

	// Check if the L1 chain has reorged at first.
	if err := h.checkL1Reorg(ctx, proposalID, meta); err != nil {
		if errors.Is(err, errL1Reorged) {
			end()
			return nil
		}

		return err
	}

	// If the current batch is handled, just skip it.
	if proposalID.Uint64() <= h.sharedState.GetLastHandledProposalID() {
		return nil
	}

	log.Info(
		"New Proposed event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"proposalID", proposalID,
		"lastBlockID", header.Number,
		"proposer", meta.GetProposer(),
		"proposalTimestamp", meta.Shasta().GetTimestamp(),
		"derivationSources", len(event.Sources),
	)

	metrics.ProverReceivedProposedBlockGauge.Set(float64(proposalID.Uint64()))

	// Move l1Current cursor.
	newL1Current, err := h.rpc.L1.HeaderByHash(ctx, meta.GetRawBlockHash())
	if err != nil {
		return err
	}
	h.sharedState.SetL1Current(newL1Current)
	h.sharedState.SetLastHandledProposalID(proposalID.Uint64())

	// Try generating a proof for the proposed block with the given backoff policy.
	go func() {
		if err := backoff.Retry(
			func() error {
				if err := h.checkExpirationAndSubmitProof(
					ctx,
					meta,
					proposalID,
					meta.GetProposer(),
				); err != nil {
					log.Error(
						"Failed to check proof status and submit proof",
						"proposalID", proposalID,
						"derivationSources", len(event.Sources),
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
			log.Error("Handle proposed event error", "error", err)
		}
	}()

	return nil
}

// checkExpirationAndSubmitProof checks whether the proposed proposal's proving window is expired,
// and submits a new proof if necessary.
func (h *ProposalEventHandler) checkExpirationAndSubmitProof(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	proposalID *big.Int,
	designatedProver common.Address,
) error {
	coreState, err := h.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get core state: %w", err)
	}

	if proposalID.Cmp(coreState.LastFinalizedProposalId) <= 0 {
		log.Info(
			"📋 Proposal has been verified",
			"proposalID", proposalID,
			"lastFinalizedProposalId", coreState.LastFinalizedProposalId,
		)
		return nil
	}

	windowExpired, _, timeToExpire, err := IsProvingWindowExpired(h.rpc, meta)
	if err != nil {
		return fmt.Errorf("failed to check if the proving window is expired: %w", err)
	}

	// If the proving window is not expired, we need to check if the current prover is the assigned prover,
	// if no and the current prover wants to prove unassigned proposals, then we should wait for its expiration.
	if !windowExpired && !h.shouldProve(designatedProver) {
		log.Info(
			"Proposed proposal is not provable by current prover at the moment",
			"proposalID", meta.Shasta().GetEventData().Id,
			"designatedProver", designatedProver,
			"timeToExpire", timeToExpire,
			"localProposerAddresses", h.localProposerAddresses,
		)

		if h.proveUnassignedProposals {
			log.Info(
				"Add proposed proposal to wait for proof window expiration",
				"proposalID", meta.Shasta().GetEventData().Id,
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

	// If the current prover is not the assigned prover, and `--prover.proveUnassignedProposals` is not set,
	// we should skip proving this proposal.
	if !h.proveUnassignedProposals && !h.shouldProve(designatedProver) {
		log.Info(
			"Expired proposal is not provable by current prover",
			"proposalID", meta.Shasta().GetEventData().Id,
			"currentProver", h.proverAddress,
			"designatedProver", designatedProver,
			"localProposerAddresses", h.localProposerAddresses,
		)
		return nil
	}

	log.Info(
		"Proposed proposal is provable",
		"proposalID", meta.Shasta().GetEventData().Id,
		"designatedProver", designatedProver,
		"localProposerAddresses", h.localProposerAddresses,
	)

	metrics.ProverProofsAssigned.Add(1)

	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}

	return nil
}
