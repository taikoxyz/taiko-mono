package handler

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// TransitionContestedEventHandler is responsible for handling the TransitionContested event.
type TransitionContestedEventHandler struct {
	rpc               *rpc.Client
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
	contesterMode     bool
}

// NewTransitionContestedEventHandler creates a new TransitionContestedEventHandler instance.
func NewTransitionContestedEventHandler(
	rpc *rpc.Client,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
	contesterMode bool,
) *TransitionContestedEventHandler {
	return &TransitionContestedEventHandler{rpc, proofSubmissionCh, contesterMode}
}

// Handle implements the TransitionContestedHandler interface.
func (h *TransitionContestedEventHandler) Handle(
	ctx context.Context,
	e *bindings.TaikoL1ClientTransitionContested,
) error {
	log.Info(
		"🗡 Transition contested",
		"blockID", e.BlockId,
		"parentHash", common.Bytes2Hex(e.Tran.ParentHash[:]),
		"hash", common.Bytes2Hex(e.Tran.BlockHash[:]),
		"stateRoot", common.BytesToHash(e.Tran.StateRoot[:]),
		"contester", e.Contester,
		"bond", utils.WeiToEther(e.ContestBond),
	)

	// If this prover is not in contester mode, we simply output a log and return.
	if !h.contesterMode {
		return nil
	}

	contestedTransition, err := h.rpc.TaikoL1.GetTransition0(
		&bind.CallOpts{Context: ctx},
		e.BlockId.Uint64(),
		e.Tran.ParentHash,
	)
	if err != nil {
		return err
	}

	// Compare the contested transition to the block in local L2 canonical chain.
	isValid, err := isValidProof(
		ctx,
		h.rpc,
		e.BlockId,
		e.Tran.ParentHash,
		contestedTransition.BlockHash,
		contestedTransition.StateRoot,
	)
	if err != nil {
		return err
	}
	if isValid {
		log.Info(
			"Contested transition is valid to local canonical chain, ignore the contest",
			"blockID", e.BlockId,
			"parentHash", common.Bytes2Hex(e.Tran.ParentHash[:]),
			"hash", common.Bytes2Hex(contestedTransition.BlockHash[:]),
			"stateRoot", common.BytesToHash(contestedTransition.StateRoot[:]),
			"contester", e.Contester,
			"bond", utils.WeiToEther(e.ContestBond),
		)
		return nil
	}

	// If the proof is invalid, we contest it.
	blockInfo, err := h.rpc.GetL2BlockInfo(ctx, e.BlockId)
	if err != nil {
		return err
	}

	meta, err := getMetadataFromBlockID(
		ctx,
		h.rpc,
		e.BlockId,
		new(big.Int).SetUint64(blockInfo.ProposedIn),
	)
	if err != nil {
		return err
	}

	go func() {
		h.proofSubmissionCh <- &proofProducer.ProofRequestBody{
			Tier: e.Tier + 1, // We need to send a higher tier proof to resolve the current contest.
			Meta: meta,
		}
	}()

	return nil
}
