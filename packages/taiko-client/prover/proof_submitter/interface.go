package submitter

import (
	"context"
	"errors"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	_ Submitter = (*ProofSubmitterShasta)(nil)

	ErrInvalidProof  = errors.New("invalid proof found")
	ErrCacheNotFound = errors.New("cache not found")
)

const (
	MaxNumSupportedZkTypes    = 2
	MaxNumSupportedProofTypes = 3
	maxProofRequestTimeout    = 1 * time.Hour
)

// Submitter is the interface for submitting proofs of the L2 blocks.
type Submitter interface {
	RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error
	BatchSubmitProofs(ctx context.Context, proofsWithHeaders *proofProducer.BatchProofs) error
	AggregateProofsByType(ctx context.Context, proofType proofProducer.ProofType) error
	FlushCache(ctx context.Context, proofType proofProducer.ProofType) error
	ClearProofBuffers(batchProof *proofProducer.BatchProofs, resend bool) error
}
