package handler

import (
	"context"
	"fmt"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
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
	e *ontakeBindings.TaikoL1ClientTransitionProvedV2,
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
	meta, err := getMetadataFromBlockIDOntake(ctx, h.rpc, e.BlockId, new(big.Int).SetUint64(e.ProposedIn))
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
		meta, err := getMetadataFromBlockIDOntake(
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

// Handle implements the TransitionProvedHandler interface.
func (h *TransitionProvedEventHandler) HandlePacaya(
	ctx context.Context,
	e *pacayaBindings.TaikoInboxClientBatchesProved,
) error {
	if len(e.BatchIds) == 0 {
		return nil
	}
	if len(e.Transitions) == len(e.BatchIds) {
		log.Error("Invalid BatchesProved number of transitions and batch IDs do not match", "batchIDs", e.BatchIds)
		return nil
	}

	for _, batchID := range e.BatchIds {
		metrics.ProverReceivedProvenBlockGauge.Set(float64(batchID))

		// Check if transition is valid.
		block, err := h.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(batchID))
		if err != nil {
			return fmt.Errorf("failed to get block by number: %w", err)
		}
		if block.Hash() != common.BytesToHash(e.Transitions[len(e.BatchIds)-1].BlockHash[:]) {
			log.Error(
				"Invalid transition proof, will try submitting a new proof",
				"batchID", batchID,
				"expectedHash", block.Hash(),
				"actualHash", common.BytesToHash(e.Transitions[len(e.BatchIds)-1].BlockHash[:]),
			)

			batch, err := h.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(batchID))
			if err != nil {
				return fmt.Errorf("failed to get batch by ID: %w", err)
			}

			meta, err := getMetadataFromBatchPacaya(ctx, h.rpc, batch)
			if err != nil {
				return fmt.Errorf("failed to get metadata from batch (%d): %w", batchID, err)
			}

			h.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
		}
	}

	return nil
}
