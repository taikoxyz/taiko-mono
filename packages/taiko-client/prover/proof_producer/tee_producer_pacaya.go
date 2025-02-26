package producer

import (
	"context"
	"fmt"
	"golang.org/x/sync/errgroup"
	"math/big"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// TEEProofProducerPacaya generates a SGX proof for the given block.
type TEEProofProducerPacaya struct {
	TrustedProducer TrustedProofProducer
	TeeProducer     TrustedProofProducer
}

// RequestProof implements the ProofProducer interface.
func (t *TEEProofProducerPacaya) RequestProof(
	ctx context.Context,
	opts ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	requestAt time.Time,
) (*ProofResponse, error) {
	g := new(errgroup.Group)

	g.Go(func() error {
		if _, err := t.TrustedProducer.RequestProof(ctx, opts, batchID, meta, requestAt); err != nil {
			return err
		}
		return nil
	})
	g.Go(func() error {
		if _, err := t.TeeProducer.RequestProof(ctx, opts, batchID, meta, requestAt); err != nil {
			return err
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get proofs: %w", err)
	}
	return &ProofResponse{
		BlockID:   batchID,
		Meta:      meta,
		Opts:      opts,
		ProofType: t.TeeProducer.ProofType,
	}, nil
}

// Aggregate implements the ProofProducer interface to aggregate a batch of proofs.
func (t *TEEProofProducerPacaya) Aggregate(
	ctx context.Context,
	items []*ProofResponse,
	startTime time.Time,
) (*BatchProofs, error) {
	if len(items) == 0 {
		return nil, ErrInvalidLength
	}
	batchIDs := make([]*big.Int, len(items))
	for i, item := range items {
		batchIDs[i] = item.Meta.Ontake().GetBlockID()
	}

	var (
		g                  = new(errgroup.Group)
		trustedBatchProofs *BatchProofs
		sgxBatchProofs     *BatchProofs
		err                error
	)

	g.Go(func() error {
		if trustedBatchProofs, err = t.TrustedProducer.Aggregate(ctx, items, startTime); err != nil {
			return err
		}
		return nil
	})
	g.Go(func() error {
		if sgxBatchProofs, err = t.TeeProducer.Aggregate(ctx, items, startTime); err != nil {
			return err
		}
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to get batches proofs: %w", err)
	}
	return &BatchProofs{
		ProofResponses:       sgxBatchProofs.ProofResponses,
		BatchProof:           sgxBatchProofs.BatchProof,
		BlockIDs:             batchIDs,
		ProofType:            sgxBatchProofs.ProofType,
		Verifier:             sgxBatchProofs.Verifier,
		TrustedProofVerifier: trustedBatchProofs.Verifier,
		TrustedBatchProof:    trustedBatchProofs.BatchProof,
	}, nil
}

// RequestCancel implements the ProofProducer interface to cancel the proof generating progress.
func (t *TEEProofProducerPacaya) RequestCancel(
	_ context.Context,
	_ ProofRequestOptions,
) error {
	// TODO: waiting raiko api specific
	return nil
}

// Tier implements the ProofProducer interface.
func (t *TEEProofProducerPacaya) Tier() uint16 {
	return encoding.TierDeprecated
}
