package handler

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// BatchesProvedEventHandler is responsible for handling the BatchesProved event.
type BatchesProvedEventHandler struct {
	rpc               *rpc.Client
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
}

// NewBatchesProvedEventHandler creates a new BatchesProvedEventHandler instance.
func NewBatchesProvedEventHandler(
	rpc *rpc.Client,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
) *BatchesProvedEventHandler {
	return &BatchesProvedEventHandler{rpc, proofSubmissionCh}
}

// Handle implements the BatchesProvedHandler interface.
func (h *BatchesProvedEventHandler) HandlePacaya(
	ctx context.Context,
	e *pacayaBindings.TaikoInboxClientBatchesProved,
) error {
	if len(e.BatchIds) == 0 {
		return nil
	}
	if len(e.Transitions) != len(e.BatchIds) {
		log.Error("Number of transitions and batch IDs do not match in a BatchesProved event", "batchIDs", e.BatchIds)
		return nil
	}

	for _, batchID := range e.BatchIds {
		batch, err := h.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(batchID))
		if err != nil {
			return fmt.Errorf("failed to get batch by ID: %w", err)
		}
		metrics.ProverReceivedProvenBlockGauge.Set(float64(batch.LastBlockId))

		status, err := rpc.GetBatchProofStatus(ctx, h.rpc, new(big.Int).SetUint64(batchID))
		if err != nil {
			return fmt.Errorf("failed to get batch proof status: %w", err)
		}
		// If the batch proof is valid, we skip it.
		if status.IsSubmitted && !status.Invalid {
			log.Info("New valid proven batch received", "batchID", batchID, "lastBatchID", batch.LastBlockId)
			continue
		}
		// Otherwise, the proof onchain is either invalid or missed, we need to submit a new proof.
		meta, err := getMetadataFromBatchPacaya(ctx, h.rpc, batch)
		if err != nil {
			return fmt.Errorf("failed to fetch metadata for batch (%d): %w", batchID, err)
		}

		h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
	}

	return nil
}

// HandleShasta implements the BatchesProvedHandler interface.
func (h *BatchesProvedEventHandler) HandleShasta(
	ctx context.Context,
	e *shastaBindings.ShastaInboxClientProved,
) error {
	payload, err := h.rpc.DecodeProvedEventPayload(&bind.CallOpts{Context: ctx}, e.Data)
	if err != nil {
		return fmt.Errorf("failed to decode proved payload: %w", err)
	}

	if len(payload.Input.Commitment.Transitions) == 0 {
		log.Warn(
			"Received Shasta proved event with zero transitions",
			"firstProposalID", payload.Input.Commitment.FirstProposalId,
		)
		return nil
	}

	// Update the latest verified proposal ID metric.
	transactionsLen := len(payload.Input.Commitment.Transitions)
	lastProposalID := payload.Input.Commitment.FirstProposalId.Uint64() + uint64(transactionsLen) - 1
	metrics.ProverLatestVerifiedIDGauge.Set(float64(lastProposalID))

	log.Info(
		"New valid proven Shasta batch received",
		"proposalID", lastProposalID,
		"checkpointBlockID", payload.Input.Commitment.EndBlockNumber,
		"checkpointBlockHash", common.Hash(payload.Input.Commitment.Transitions[transactionsLen-1].BlockHash),
	)

	return nil
}
