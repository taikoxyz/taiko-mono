package producer

import (
	"bytes"
	"math/big"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// DummyProofProducer always returns a dummy proof.
type DummyProofProducer struct{}

// RequestProof returns a dummy proof to the result channel.
func (o *DummyProofProducer) RequestProof(
	opts ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
	_ time.Time,
) (*ProofResponse, error) {
	return &ProofResponse{BatchID: blockID, Meta: meta, Proof: bytes.Repeat([]byte{0xff}, 100), Opts: opts}, nil
}

// RequestBatchProofs returns a dummy proof aggregation to the result channel.
func (o *DummyProofProducer) RequestBatchProofs(proofs []*ProofResponse, proofType ProofType) (*BatchProofs, error) {
	return &BatchProofs{ProofResponses: proofs, BatchProof: bytes.Repeat([]byte{0xbb}, 100), ProofType: proofType}, nil
}
