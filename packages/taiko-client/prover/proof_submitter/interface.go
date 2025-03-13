package submitter

import (
	"context"
	"errors"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	_                              Submitter = (*ProofSubmitterOntake)(nil)
	submissionDelayRandomBumpRange float64   = 20
	proofPollingInterval                     = 10 * time.Second
	ProofTimeout                             = 3 * time.Hour
	ErrInvalidProof                          = errors.New("invalid proof found")
)

// Submitter is the interface for submitting proofs of the L2 blocks.
type Submitter interface {
	RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error
	// SubmitProof @dev this function would be deprecated after Pacaya fork
	SubmitProof(ctx context.Context, proofResponse *proofProducer.ProofResponse) error
	BatchSubmitProofs(ctx context.Context, proofsWithHeaders *proofProducer.BatchProofs) error
	// AggregateProofs @dev this function would be deprecated after Pacaya fork
	AggregateProofs(ctx context.Context) error
	// Producer @dev this function would be deprecated after Pacaya fork
	Producer() proofProducer.ProofProducer
	// Tier @dev this function would be deprecated after Pacaya fork
	Tier() uint16
	// BufferSize @dev this function would be deprecated after Pacaya fork
	BufferSize() uint64
	// AggregationEnabled @dev this function would be deprecated after Pacaya fork
	AggregationEnabled() bool
	AggregateProofsByType(ctx context.Context, proofType string) error
}

// Contester is the interface for contesting proofs of the L2 blocks.
type Contester interface {
	SubmitContest(
		ctx context.Context,
		blockID *big.Int,
		proposedIn *big.Int,
		parentHash common.Hash,
		meta metadata.TaikoProposalMetaData,
		tier uint16,
	) error
}
