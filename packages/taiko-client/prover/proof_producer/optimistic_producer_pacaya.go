package producer

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

const (
	ProofTypeOP = "op"
)

// OptimisticProofProducerPacaya always returns an optimistic (dummy) proof.
type OptimisticProofProducerPacaya struct {
	Verifier common.Address
	OptimisticProofProducer
	TrustedProofProducer
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (o *OptimisticProofProducerPacaya) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	startTime time.Time,
) (*BatchProofs, error) {
	if batchProof, err := o.OptimisticProofProducer.Aggregate(ctx, items, startTime); err != nil {
		return nil, err
	} else {
		batchProof.Verifier = o.Verifier
		return batchProof, nil
	}
}

// Tier implements the ProofProducer interface.
func (o *OptimisticProofProducerPacaya) Tier() uint16 {
	return encoding.TierOptimisticID
}
