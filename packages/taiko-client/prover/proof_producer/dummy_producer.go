package producer

import (
	"bytes"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-client/bindings"
)

// DummyProofProducer always returns a dummy proof.
type DummyProofProducer struct{}

// RequestProof returns a dummy proof to the result channel.
func (o *DummyProofProducer) RequestProof(
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	header *types.Header,
	tier uint16,
) (*ProofWithHeader, error) {
	return &ProofWithHeader{
		BlockID: blockID,
		Meta:    meta,
		Header:  header,
		Proof:   bytes.Repeat([]byte{0xff}, 100),
		Opts:    opts,
		Tier:    tier,
	}, nil
}
