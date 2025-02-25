package producer

import (
	"context"
	"fmt"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"golang.org/x/sync/errgroup"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

// SGXProofProducerPacaya generates a SGX proof for the given block.
type SGXProofProducerPacaya struct {
	trustedProducer TrustedProofProducer
	sgxProducer     TrustedProofProducer
}

// RequestProof implements the ProofProducer interface.
func (s *SGXProofProducerPacaya) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	var (
		g = new(errgroup.Group)
	)
	g.Go(func() error {
		trusted, err := s.trustedProducer.requestProof()
		if err != nil {
			return fmt.Errorf(
				"failed to fetch l2 Header, blockID: %d, error: %w",
				meta.Pacaya().GetLastBlockID(),
				err,
			)
		}
		return nil
	})
	g.Go(func() error {
		sgx, err := s.sgxProducer.requestProof()
		if err != nil {
			return fmt.Errorf(
				"failed to fetch l2 Header, blockID: %d, error: %w",
				meta.Pacaya().GetLastBlockID(),
				err,
			)
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return fmt.Errorf("failed to fetch headers: %w", err)
	}

}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (s *SGXProofProducerPacaya) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	startTime time.Time,
) (*BatchProofs, error) {
	if batchProof, err := o.OptimisticProofProducer.Aggregate(ctx, items, startTime); err != nil {
		return nil, err
	} else {
		batchProof = s.Verifier
		return batchProof, nil
	}
}

// Tier implements the ProofProducer interface.
func (s *SGXProofProducerPacaya) Tier() uint16 {
	return encoding.TierDeprecated
}
