package handler

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// AssignmentExpiredEventHandler is responsible for handling the expiration of proof assignments.
type AssignmentExpiredEventHandler struct {
	rpc               *rpc.Client
	proverAddress     common.Address
	proverSetAddress  common.Address
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
}

// NewAssignmentExpiredEventHandler creates a new AssignmentExpiredEventHandler instance.
func NewAssignmentExpiredEventHandler(
	rpc *rpc.Client,
	proverAddress common.Address,
	proverSetAddress common.Address,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
) *AssignmentExpiredEventHandler {
	return &AssignmentExpiredEventHandler{
		rpc,
		proverAddress,
		proverSetAddress,
		proofSubmissionCh,
	}
}

// Handle implements the AssignmentExpiredHandler interface.
func (h *AssignmentExpiredEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
) error {
	var (
		proofStatus *rpc.BatchProofStatus
		err         error
	)

	// Check if we still need to generate a new proof for that batch.
	log.Info(
		"Proof assignment window is expired",
		"batchID", meta.Pacaya().GetBatchID(),
		"assignedProver", meta.GetProposer(),
	)
	if proofStatus, err = rpc.GetBatchProofStatus(ctx, h.rpc, meta.Pacaya().GetBatchID()); err != nil {
		return err
	}

	if !proofStatus.IsSubmitted {
		go func() { h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta} }()
		return nil
	}

	// If there is already a proof submitted and there is no need to contest
	// it, we skip proving this block here.
	if !proofStatus.Invalid {
		return nil
	}

	// Submit a proof to protocol.
	go func() { h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta} }()

	return nil
}
