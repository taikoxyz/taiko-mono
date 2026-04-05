package handler

import (
	"context"
	"fmt"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// AssignmentExpiredEventHandler is responsible for handling the expiration of proof assignments.
type AssignmentExpiredEventHandler struct {
	rpc               *rpc.Client
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
}

// NewAssignmentExpiredEventHandler creates a new AssignmentExpiredEventHandler instance.
func NewAssignmentExpiredEventHandler(
	rpc *rpc.Client,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
) *AssignmentExpiredEventHandler {
	return &AssignmentExpiredEventHandler{
		rpc,
		proofSubmissionCh,
	}
}

// Handle implements the AssignmentExpiredHandler interface.
func (h *AssignmentExpiredEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
) error {
	if meta.IsShasta() {
		proposalID := meta.Shasta().GetEventData().Id
		coreState, err := h.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
		if err != nil {
			return fmt.Errorf("failed to get Shasta core state: %w", err)
		}

		// If the proposal is already finalized, skip it.
		if proposalID.Cmp(coreState.LastFinalizedProposalId) <= 0 {
			log.Info(
				"Shasta proposal already finalized, skip proof submission",
				"proposalID", proposalID,
				"lastFinalizedProposalId", coreState.LastFinalizedProposalId,
			)
			return nil
		}

		log.Info(
			"Proof assignment window expired",
			"proposalID", proposalID,
			"assignedProver", meta.GetProposer(),
		)
		go func() { h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta} }()
		return nil
	}
	return nil
}
