package handler

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	shastaIndexer "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/state_indexer"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// BatchesProvedEventHandler is responsible for handling the BatchesProved event.
type BatchesProvedEventHandler struct {
	rpc               *rpc.Client
	shastaIndexer     *shastaIndexer.Indexer
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
}

// NewBatchesProvedEventHandler creates a new BatchesProvedEventHandler instance.
func NewBatchesProvedEventHandler(
	rpc *rpc.Client,
	shastaIndexer *shastaIndexer.Indexer,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
) *BatchesProvedEventHandler {
	return &BatchesProvedEventHandler{rpc, shastaIndexer, proofSubmissionCh}
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
	payload, err := encoding.DecodeProvedEvent(e.Data)
	if err != nil {
		return fmt.Errorf("failed to decode proved payload: %w", err)
	}

	header, err := h.rpc.L2.HeaderByNumber(ctx, payload.Transition.Checkpoint.BlockNumber)
	if err != nil {
		return fmt.Errorf("failed to get header by number: %w", err)
	}

	if header.Hash() == payload.Transition.Checkpoint.BlockHash {
		log.Info("New valid proven Shasta batch received", "batchID", payload.ProposalId, "lastBatchID", header.Number)
		return nil
	}

	// Otherwise, the proof onchain is invalid, we need to submit a new proof.
	proposal, err := h.shastaIndexer.GetProposalByID(payload.ProposalId.Uint64())
	if err != nil {
		return fmt.Errorf("failed to fetch proposal metadata for Shasta: %w", err)
	}
	h.proofSubmissionCh <- &proofProducer.ProofRequestBody{
		Meta: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.IInboxProposedEventPayload{
				Proposal:   *proposal.Proposal,
				Derivation: *proposal.Derivation,
				CoreState:  *proposal.CoreState,
			},
			types.Log{}, // NOTE: we don't use the log in the prover anyway.
		),
	}

	return nil
}
