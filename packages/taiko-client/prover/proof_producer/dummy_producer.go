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
	tier uint16,
	_ time.Time,
) (*ProofResponse, error) {
	if meta.IsPacaya() {
		return &ProofResponse{
			BlockID:   blockID,
			Meta:      meta,
			Proof:     bytes.Repeat([]byte{0xff}, 100),
			Opts:      opts,
			ProofType: ProofTypeOP,
		}, nil
	} else {
		return &ProofResponse{
			BlockID: blockID,
			Meta:    meta,
			Proof:   bytes.Repeat([]byte{0xff}, 100),
			Opts:    opts,
			Tier:    tier,
		}, nil
	}
}

// RequestBatchProofs returns a dummy proof aggregation to the result channel.
func (o *DummyProofProducer) RequestBatchProofs(
	proofs []*ProofResponse,
	tier uint16,
	proofType string,
) (*BatchProofs, error) {
	if len(proofType) == 0 {
		return &BatchProofs{
			ProofResponses: proofs,
			BatchProof:     bytes.Repeat([]byte{0xbb}, 100),
			Tier:           tier,
		}, nil
	} else {
		return &BatchProofs{
			ProofResponses: proofs,
			BatchProof:     bytes.Repeat([]byte{0xbb}, 100),
			ProofType:      proofType,
		}, nil
	}

}
