package producer

import (
	"bytes"
	"context"
	"math/big"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// DummyProofProducer always returns a dummy proof.
type DummyProofProducer struct{}

// RequestProof returns a dummy proof to the result channel.
func (o *DummyProofProducer) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	return &ProofResponse{BatchID: batchID, Meta: meta, Proof: bytes.Repeat([]byte{0xff}, 100), Opts: opts}, nil
}

// Aggregate returns a dummy proof aggregation to the result channel.
func (o *DummyProofProducer) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	requestAt time.Time,
) (*BatchProofs, error) {
	return &BatchProofs{ProofResponses: items, BatchProof: bytes.Repeat([]byte{0xff}, 100), ProofType: ProofTypeOp}, nil
}

// RequestBatchProofs returns a dummy proof aggregation to the result channel.
func (o *DummyProofProducer) RequestBatchProofs(proofs []*ProofResponse, proofType ProofType) (*BatchProofs, error) {
	return &BatchProofs{ProofResponses: proofs, BatchProof: bytes.Repeat([]byte{0xbb}, 100), ProofType: proofType}, nil
}
