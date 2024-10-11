package submitter

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// Submitter is the interface for submitting proofs of the L2 blocks.
type Submitter interface {
	RequestProof(ctx context.Context, meta metadata.TaikoBlockMetaData) error
	Producer() proofProducer.ProofProducer
	Tier() uint16
}
