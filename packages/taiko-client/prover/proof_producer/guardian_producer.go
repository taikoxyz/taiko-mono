package producer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

// GuardianProofProducer always returns an optimistic (dummy) proof.
type GuardianProofProducer struct {
	DummyProofProducer
	returnLivenessBond bool
	tier               uint16
}

func NewGuardianProofProducer(
	tier uint16,
	returnLivenessBond bool,
) *GuardianProofProducer {
	return &GuardianProofProducer{
		DummyProofProducer: DummyProofProducer{},
		returnLivenessBond: returnLivenessBond,
		tier:               tier,
	}
}

// RequestProof implements the ProofProducer interface.
func (g *GuardianProofProducer) RequestProof(
	_ context.Context,
	opts *ProofRequestOptions,
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	header *types.Header,
) (*ProofWithHeader, error) {
	log.Info(
		"Request guardian proof",
		"blockID", blockID,
		"coinbase", meta.Coinbase,
		"height", header.Number,
		"hash", header.Hash(),
	)

	if g.returnLivenessBond {
		return &ProofWithHeader{
			BlockID: blockID,
			Meta:    meta,
			Header:  header,
			Proof:   crypto.Keccak256([]byte("RETURN_LIVENESS_BOND")),
			Opts:    opts,
			Tier:    g.tier,
		}, nil
	}

	return g.DummyProofProducer.RequestProof(opts, blockID, meta, header, g.Tier())
}

func (g *GuardianProofProducer) RequestCancel(
	_ context.Context,
	_ *ProofRequestOptions,
) error {
	return nil
}

// Tier implements the ProofProducer interface.
func (g *GuardianProofProducer) Tier() uint16 {
	return g.tier
}
