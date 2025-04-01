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
