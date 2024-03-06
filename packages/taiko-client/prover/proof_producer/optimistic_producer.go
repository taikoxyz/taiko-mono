package producer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
)

// OptimisticProofProducer always returns an optimistic (dummy) proof.
type OptimisticProofProducer struct{ *DummyProofProducer }

// RequestProof implements the ProofProducer interface.
func (o *OptimisticProofProducer) RequestProof(
	ctx context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	header *types.Header,
) (*ProofWithHeader, error) {
	log.Info(
		"Request optimistic proof",
		"blockID", blockID,
		"coinbase", meta.Coinbase,
		"height", header.Number,
		"hash", header.Hash(),
	)

	return o.DummyProofProducer.RequestProof(ctx, opts, blockID, meta, header, o.Tier())
}

// Tier implements the ProofProducer interface.
func (o *OptimisticProofProducer) Tier() uint16 {
	return encoding.TierOptimisticID
}

// Cancellable implements the ProofProducer interface.
func (o *OptimisticProofProducer) Cancellable() bool {
	return false
}

// Cancel cancels an existing proof generation.
func (o *OptimisticProofProducer) Cancel(ctx context.Context, blockID *big.Int) error {
	return nil
}
