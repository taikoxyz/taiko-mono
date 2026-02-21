package handler

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
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
	coreState, err := h.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta core state: %w", err)
	}

	header, err := h.rpc.L2.HeaderByHash(ctx, coreState.LastFinalizedBlockHash)
	if err != nil {
		return fmt.Errorf("failed to get L2 header by hash: %w", err)
	}
	metrics.ProverLatestVerifiedIDGauge.Set(float64(header.Number.Uint64()))

	log.Info(
		"New valid proven Shasta batch received",
		"firstProposalID", e.FirstNewProposalId,
		"lastProposalID", e.LastProposalId,
		"actualProver", e.ActualProver,
		"checkpointBlockHash", coreState.LastFinalizedBlockHash,
	)

	return nil
}
