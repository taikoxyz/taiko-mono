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
	meta metadata.TaikoProposalMetaData,
) error {
	var (
		proofStatus *rpc.BlockProofStatus
		err         error
	)
	// Check if we still need to generate a new proof for that block.
	if meta.IsPacaya() {
		log.Info(
			"Proof assignment window is expired",
			"batchID", meta.Pacaya().GetBatchID(),
			"assignedProver", meta.GetProposer(),
		)
		if proofStatus, err = rpc.GetBatchProofStatus(
			ctx,
			h.rpc,
			meta.Pacaya().GetBatchID(),
		); err != nil {
			return err
		}
	} else {
		log.Info(
			"Proof assignment window is expired",
			"blockID", meta.Ontake().GetBlockID(),
			"assignedProver", meta.Ontake().GetAssignedProver(),
			"minTier", meta.Ontake().GetMinTier(),
		)
		if proofStatus, err = rpc.GetBlockProofStatus(
			ctx,
			h.rpc,
			meta.Ontake().GetBlockID(),
			h.proverAddress,
			h.proverSetAddress,
		); err != nil {
			return err
		}
	}

	if !proofStatus.IsSubmitted {
		reqBody := &proofProducer.ProofRequestBody{Meta: meta}
		if !meta.IsPacaya() {
			reqBody.Tier = meta.Ontake().GetMinTier()
		}
		go func() { h.proofSubmissionCh <- reqBody }()
		return nil
	}
	// If there is already a proof submitted and there is no need to contest
	// it, we skip proving this block here.
	if !proofStatus.Invalid || !h.contesterMode {
		return nil
	}

	// If there is no contester, we submit a contest to protocol.
	go func() {
		if meta.IsPacaya() {
			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
			return
		}
		if proofStatus.CurrentTransitionState.Contester == rpc.ZeroAddress && !h.isGuardian {
			h.proofContestCh <- &proofProducer.ContestRequestBody{
				BlockID:    meta.Ontake().GetBlockID(),
				ProposedIn: meta.Ontake().GetRawBlockHeight(),
				ParentHash: proofStatus.ParentHeader.Hash(),
				Meta:       meta,
				Tier:       proofStatus.CurrentTransitionState.Tier,
			}
		} else {
			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{
				Tier: proofStatus.CurrentTransitionState.Tier + 1,
				Meta: meta,
			}
		}
	}()

	return nil
}
