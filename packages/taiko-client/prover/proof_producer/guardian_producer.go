package producer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings"
)

// GuardianProofProducer always returns an optimistic (dummy) proof.
type GuardianProofProducer struct {
	returnLivenessBond bool
	tier               uint16
	*SGXProofProducer
}

func NewGuardianProofProducer(
	sgxProofProducer *SGXProofProducer,
	tier uint16,
	returnLivenessBond bool,
) *GuardianProofProducer {
	return &GuardianProofProducer{
		SGXProofProducer:   sgxProofProducer,
		returnLivenessBond: returnLivenessBond,
		tier:               tier,
	}
}

// RequestProof implements the ProofProducer interface.
func (g *GuardianProofProducer) RequestProof(
	ctx context.Context,
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

	// Each guardian prover should check the block hash with raiko at first,
	// before submitting the guardian proof, if raiko can return a proof without
	// any error, which means the block hash is valid.
	if _, err := g.SGXProofProducer.RequestProof(ctx, opts, blockID, meta, header); err != nil {
		return nil, err
	}

	return g.DummyProofProducer.RequestProof(opts, blockID, meta, header, g.Tier())
}

// Tier implements the ProofProducer interface.
func (g *GuardianProofProducer) Tier() uint16 {
	return g.tier
}
