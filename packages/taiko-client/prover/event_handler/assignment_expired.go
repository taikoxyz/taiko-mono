package handler

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// AssignmentExpiredEventHandler is responsible for handling the expiration of proof assignments.
type AssignmentExpiredEventHandler struct {
	rpc               *rpc.Client
	proverAddress     common.Address
	proverSetAddress  common.Address
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
	proofContestCh    chan<- *proofProducer.ContestRequestBody
	contesterMode     bool
	// Guardian prover related.
	isGuardian bool
}

// NewAssignmentExpiredEventHandler creates a new AssignmentExpiredEventHandler instance.
func NewAssignmentExpiredEventHandler(
	rpc *rpc.Client,
	proverAddress common.Address,
	proverSetAddress common.Address,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
	proofContestCh chan *proofProducer.ContestRequestBody,
	contesterMode bool,
	isGuardian bool,
) *AssignmentExpiredEventHandler {
	return &AssignmentExpiredEventHandler{
		rpc,
		proverAddress,
		proverSetAddress,
		proofSubmissionCh,
		proofContestCh,
		contesterMode,
		isGuardian,
	}
}

// Handle implements the AssignmentExpiredHandler interface.
func (h *AssignmentExpiredEventHandler) Handle(
	ctx context.Context,
	e *bindings.TaikoL1ClientBlockProposed,
) error {
	log.Info(
		"Proof assignment window is expired",
		"blockID", e.BlockId,
		"assignedProver", e.AssignedProver,
		"minTier", e.Meta.MinTier,
	)

	// Check if we still need to generate a new proof for that block.
	proofStatus, err := rpc.GetBlockProofStatus(ctx, h.rpc, e.BlockId, h.proverAddress, h.proverSetAddress)
	if err != nil {
		return err
	}
	if !proofStatus.IsSubmitted {
		go func() {
			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Tier: e.Meta.MinTier, Event: e}
		}()
		return nil
	}
	// If there is already a proof submitted and there is no need to contest
	// it, we skip proving this block here.
	if !proofStatus.Invalid || !h.contesterMode {
		return nil
	}

	// If there is no contester, we submit a contest to protocol.
	go func() {
		if proofStatus.CurrentTransitionState.Contester == rpc.ZeroAddress && !h.isGuardian {
			h.proofContestCh <- &proofProducer.ContestRequestBody{
				BlockID:    e.BlockId,
				ProposedIn: new(big.Int).SetUint64(e.Raw.BlockNumber),
				ParentHash: proofStatus.ParentHeader.Hash(),
				Meta:       &e.Meta,
				Tier:       proofStatus.CurrentTransitionState.Tier,
			}
		} else {
			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{
				Tier:  proofStatus.CurrentTransitionState.Tier + 1,
				Event: e,
			}
		}
	}()

	return nil
}
