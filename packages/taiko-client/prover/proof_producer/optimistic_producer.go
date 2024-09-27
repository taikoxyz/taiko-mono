package producer

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// OptimisticProofProducer always returns an optimistic (dummy) proof.
type OptimisticProofProducer struct{ DummyProofProducer }

// RequestProof implements the ProofProducer interface.
func (o *OptimisticProofProducer) RequestProof(
	_ context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoBlockMetaData,
	header *types.Header,
	requestAt time.Time,
) (*ProofWithHeader, error) {
	log.Info(
		"Request optimistic proof",
		"blockID", blockID,
		"coinbase", meta.GetCoinbase(),
		"height", header.Number,
		"hash", header.Hash(),
	)

	return o.DummyProofProducer.RequestProof(opts, blockID, meta, header, o.Tier(), requestAt)
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (o *OptimisticProofProducer) Aggregate(
	_ context.Context,
	items []*ProofWithHeader,
	_ time.Time,
) (*BatchProofs, error) {
	log.Info(
		"Aggregate batch optimistic proof",
		"items", items,
	)
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	blockIDs := make([]*big.Int, len(items))
	for i, item := range items {
		blockIDs[i] = item.Meta.GetBlockID()
	}
	batchProof, err := o.DummyProofProducer.RequestBatchProofs(items, o.Tier())
	if err != nil {
		return nil, err
	}
	batchProof.BlockIDs = blockIDs
	return batchProof, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (o *OptimisticProofProducer) RequestCancel(
	_ context.Context,
	_ *ProofRequestOptions,
) error {
	return nil
}

// Tier implements the ProofProducer interface.
func (o *OptimisticProofProducer) Tier() uint16 {
	return encoding.TierOptimisticID
}
