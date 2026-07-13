package submitter

import (
	"context"
	"errors"
	"fmt"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	_ Submitter = (*ProofSubmitter)(nil)

	ErrInvalidProof  = errors.New("invalid proof found")
	ErrCacheNotFound = errors.New("cache not found")
)

// ReorgedProofsError is returned by BatchSubmitProofs when proofs were dropped from an
// aggregation because their proposals' source L1 blocks are no longer in the canonical chain.
// The caller must roll the proposal scan cursors back below the lowest dropped proposal, so
// that the replacement proposal events are re-scanned and re-proven; otherwise the
// already-advanced cursors would skip the re-proposed events forever.
type ReorgedProofsError struct {
	// LowestProposalID is the smallest dropped proposal ID in the aggregation.
	LowestProposalID uint64
	// LowestProposalMeta is the metadata of that proposal, from its stale pre-reorg event.
	LowestProposalMeta metadata.TaikoProposalMetaData
}

// Error implements the error interface. The message embeds ErrInvalidProof's text, so callers
// matching on that sentinel's text keep the previous drop behavior if they miss the typed error.
func (e *ReorgedProofsError) Error() string {
	return fmt.Sprintf("%s: proposal %d reorged out of the canonical L1 chain", ErrInvalidProof, e.LowestProposalID)
}

// Unwrap makes errors.Is(err, ErrInvalidProof) hold for this error.
func (e *ReorgedProofsError) Unwrap() error { return ErrInvalidProof }

const (
	MaxNumSupportedZkTypes    = 2
	MaxNumSupportedProofTypes = 3
)

// Submitter is the interface for submitting proofs of the L2 blocks.
type Submitter interface {
	RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error
	BatchSubmitProofs(ctx context.Context, proofsWithHeaders *proofProducer.BatchProofs) error
	AggregateProofsByType(ctx context.Context, proofType proofProducer.ProofType) error
	FlushCache(ctx context.Context, proofType proofProducer.ProofType) error
	ClearProofBuffers(batchProof *proofProducer.BatchProofs, resend bool) error
}
