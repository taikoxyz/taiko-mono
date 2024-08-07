package producer

import (
	"context"
	"math/big"

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
) (*ProofWithHeader, error) {
	log.Info(
		"Request optimistic proof",
		"blockID", blockID,
		"coinbase", meta.GetCoinbase(),
		"height", header.Number,
		"hash", header.Hash(),
	)

	return o.DummyProofProducer.RequestProof(opts, blockID, meta, header, o.Tier())
}

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
