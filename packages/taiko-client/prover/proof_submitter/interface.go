package submitter

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// Submitter is the interface for submitting proofs of the L2 blocks.
type Submitter interface {
	RequestProof(ctx context.Context, meta metadata.TaikoBlockMetaData) error
	SubmitProof(ctx context.Context, proofWithHeader *proofProducer.ProofWithHeader) error
	BatchSubmitProofs(ctx context.Context, proofsWithHeaders *proofProducer.BatchProofs) error
	AggregateProofs(ctx context.Context) error
	Producer() proofProducer.ProofProducer
	Tier() uint16
	BufferSize() uint64
}

// Contester is the interface for contesting proofs of the L2 blocks.
type Contester interface {
	SubmitContest(
		ctx context.Context,
		blockID *big.Int,
		proposedIn *big.Int,
		parentHash common.Hash,
		meta metadata.TaikoBlockMetaData,
		tier uint16,
	) error
}
