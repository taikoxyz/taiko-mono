package handler

import (
	"context"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// TransitionProvedEventHandler is responsible for handling the TransitionProved event.
type TransitionProvedEventHandler struct {
	rpc               *rpc.Client
	proofContestCh    chan<- *proofProducer.ContestRequestBody
	proofSubmissionCh chan<- *proofProducer.ProofRequestBody
	contesterMode     bool
	isGuardian        bool
}

// NewTransitionProvedEventHandler creates a new TransitionProvedEventHandler instance.
func NewTransitionProvedEventHandler(
	rpc *rpc.Client,
	proofContestCh chan *proofProducer.ContestRequestBody,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
	contesterMode bool,
	isGuardian bool,
) *TransitionProvedEventHandler {
	return &TransitionProvedEventHandler{
		rpc,
		proofContestCh,
		proofSubmissionCh,
		contesterMode,
		isGuardian,
	}
}

// Handle implements the TransitionProvedHandler interface.
func (h *TransitionProvedEventHandler) Handle(
	ctx context.Context,
	e *bindings.TaikoL1ClientTransitionProvedV2,
) error {
	metrics.ProverReceivedProvenBlockGauge.Set(float64(e.BlockId.Uint64()))

	if e.Tier >= encoding.TierGuardianMinorityID {
		metrics.ProverProvenByGuardianGauge.Add(1)
	}

	// If this prover is in contest mode, we check the validity of this proof and if it's invalid,
	// contest it with a higher tier proof.
	if !h.contesterMode {
		return nil
	}

	isValid, err := isValidProof(
		ctx,
		h.rpc,
		e.BlockId,
		e.Tran.ParentHash,
		e.Tran.BlockHash,
		e.Tran.StateRoot,
	)
	if err != nil {
		return err
	}
	// If the proof is valid, we simply return.
	if isValid {
		return nil
	}
	// If the proof is invalid, we contest it.
	meta, err := GetMetadataFromBlockID(ctx, h.rpc, e.BlockId, new(big.Int).SetUint64(e.ProposedIn))
	if err != nil {
		return err
	}

	log.Info(
		"Attempting to contest a proven transition",
		"blockID", e.BlockId,
		"l1Height", e.ProposedIn,
		"tier", e.Tier,
		"parentHash", common.Bytes2Hex(e.Tran.ParentHash[:]),
		"blockHash", common.Bytes2Hex(e.Tran.BlockHash[:]),
		"stateRoot", common.Bytes2Hex(e.Tran.StateRoot[:]),
	)
	if h.isGuardian {
		meta, err := GetMetadataFromBlockID(
			ctx,
			h.rpc,
			e.BlockId,
			new(big.Int).SetUint64(e.ProposedIn),
		)
		if err != nil {
			return err
		}
		go func() {
			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{
				Tier: encoding.TierGuardianMinorityID,
				Meta: meta,
			}
		}()
	} else {
		go func() {
			h.proofContestCh <- &proofProducer.ContestRequestBody{
				BlockID:    e.BlockId,
				ProposedIn: new(big.Int).SetUint64(e.ProposedIn),
				ParentHash: e.Tran.ParentHash,
				Meta:       meta,
				Tier:       e.Tier,
			}
		}()
	}
	return nil
}
