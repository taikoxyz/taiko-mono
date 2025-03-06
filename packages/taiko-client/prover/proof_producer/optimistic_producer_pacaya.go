package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

const (
	ProofTypeOp = "op"
)

// OptimisticProofProducerPacaya always returns an optimistic (dummy) proof.
type OptimisticProofProducerPacaya struct {
	OpVerifier    common.Address
	PivotVerifier common.Address
	DummyProofProducer
}

// RequestProof implements the ProofProducer interface.
func (o *OptimisticProofProducerPacaya) RequestProof(
	_ context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request pacaya optimistic proof",
		"batchID", batchID,
		"proposer", meta.GetProposer(),
	)

	return &ProofResponse{
		BlockID:   batchID,
		Meta:      meta,
		Opts:      opts,
		ProofType: ProofTypeOp,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (o *OptimisticProofProducerPacaya) Aggregate(
	_ context.Context,
	items []*ProofResponse,
	_ time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	batchIDs := make([]*big.Int, len(items))
	for i, item := range items {
		batchIDs[i] = item.Meta.Pacaya().GetBatchID()
	}

	var (
		g                = new(errgroup.Group)
		pivotBatchProofs *BatchProofs
		opBatchProofs    *BatchProofs
		err              error
	)

	g.Go(func() error {
		if pivotBatchProofs, err = o.RequestBatchProofs(items, o.Tier(), ProofTypePivot); err != nil {
			return err
		}
		return nil
	})
	g.Go(func() error {
		if opBatchProofs, err = o.RequestBatchProofs(items, o.Tier(), ProofTypeOp); err != nil {
			return err
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}
	return &BatchProofs{
		ProofResponses:     opBatchProofs.ProofResponses,
		BatchProof:         opBatchProofs.BatchProof,
		BlockIDs:           batchIDs,
		ProofType:          opBatchProofs.ProofType,
		Verifier:           o.OpVerifier,
		PivotProofVerifier: o.PivotVerifier,
		PivotBatchProof:    pivotBatchProofs.BatchProof,
		IsPacaya:           true,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (o *OptimisticProofProducerPacaya) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	return nil
}

// Tier implements the ProofProducer interface.
func (o *OptimisticProofProducerPacaya) Tier() uint16 {
	return encoding.TierDeprecated
}
