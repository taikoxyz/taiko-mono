package producer

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// OptimisticProofProducer always returns an optimistic (dummy) proof.
type OptimisticProofProducer struct{ DummyProofProducer }

// RequestProof implements the ProofProducer interface.
func (o *OptimisticProofProducer) RequestProof(
	_ context.Context,
	opts ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	log.Info(
		"Request optimistic proof",
		"blockID", blockID,
		"proposer", meta.GetProposer(),
	)

	return o.DummyProofProducer.RequestProof(opts, blockID, meta, o.Tier(), requestAt)
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (o *OptimisticProofProducer) Aggregate(
	_ context.Context,
	items []*ProofResponse,
	_ time.Time,
) (*BatchProofs, error) {
	log.Info(
		"Aggregate batch optimistic proof",
	)
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	blockIDs := make([]*big.Int, len(items))
	for i, item := range items {
		blockIDs[i] = item.Meta.Ontake().GetBlockID()
	}
	proofType := items[0].ProofType
	batchProof, err := o.DummyProofProducer.RequestBatchProofs(items, o.Tier(), proofType)
	if err != nil {
		return nil, err
	}
	batchProof.BlockIDs = blockIDs
	return batchProof, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (o *OptimisticProofProducer) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	return nil
}

// Tier implements the ProofProducer interface.
func (o *OptimisticProofProducer) Tier() uint16 {
	return encoding.TierOptimisticID
}
