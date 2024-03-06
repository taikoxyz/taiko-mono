package submitter

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

type Submitter interface {
	RequestProof(ctx context.Context, event *bindings.TaikoL1ClientBlockProposed) error
	SubmitProof(ctx context.Context, proofWithHeader *proofProducer.ProofWithHeader) error
	Producer() proofProducer.ProofProducer
	Tier() uint16
}

type Contester interface {
	SubmitContest(
		ctx context.Context,
		blockID *big.Int,
		proposedIn *big.Int,
		parentHash common.Hash,
		meta *bindings.TaikoDataBlockMetadata,
		tier uint16,
	) error
}
