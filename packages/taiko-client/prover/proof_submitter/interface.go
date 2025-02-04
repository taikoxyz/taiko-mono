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
	SubmitProof(ctx context.Context, proofResponse *proofProducer.ProofResponse) error
	BatchSubmitProofs(ctx context.Context, proofsWithHeaders *proofProducer.BatchProofs) error
	AggregateProofs(ctx context.Context) error
	Producer() proofProducer.ProofProducer
	Tier() uint16
	BufferSize() uint64
	AggregationEnabled() bool
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
