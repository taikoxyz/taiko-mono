package producer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
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
	opts ProofRequestOptions,
	blockID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	if opts.IsPacaya() {
		return nil, fmt.Errorf("guardian proofs generation is not supported for Pacaya")
	}
	log.Info(
		"Request guardian proof",
		"blockID", blockID,
		"coinbase", meta.Ontake().GetCoinbase(),
	)

	if g.returnLivenessBond {
		return &ProofResponse{
			BlockID: blockID,
			Meta:    meta,
			Proof:   crypto.Keccak256([]byte("RETURN_LIVENESS_BOND")),
			Opts:    opts,
			Tier:    g.tier,
		}, nil
	}

	return g.DummyProofProducer.RequestProof(opts, blockID, meta, g.Tier(), requestAt)
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (g *GuardianProofProducer) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	return nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (g *GuardianProofProducer) Aggregate(
	_ context.Context,
	_ []*ProofResponse,
	_ time.Time,
) (*BatchProofs, error) {
	return nil, nil
}

// Tier implements the ProofProducer interface.
func (g *GuardianProofProducer) Tier() uint16 {
	return g.tier
}
