package submitter

import (
	"fmt"

	"github.com/ethereum/go-ethereum/log"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// clearProofBufferItems removes the specified proof items from the matching proof buffer.
func clearProofBufferItems(
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
	batchProof *proofProducer.BatchProofs,
) error {
	if len(batchProof.ProofResponses) == 0 {
		return proofProducer.ErrInvalidLength
	}
	log.Info(
		"Clear proof buffers",
		"size", len(batchProof.ProofResponses),
		"firstID", batchProof.ProofResponses[0].BatchID,
		"lastID", batchProof.ProofResponses[len(batchProof.BatchIDs)-1].BatchID,
		"proofType", batchProof.ProofType,
	)

	proofBuffer, exist := proofBuffers[batchProof.ProofType]
	if !exist {
		return fmt.Errorf("unexpected proof type to clear: %s", batchProof.ProofType)
	}

	batchIDs := make([]uint64, 0, len(batchProof.ProofResponses))
	for _, proof := range batchProof.ProofResponses {
		batchIDs = append(batchIDs, proof.BatchID.Uint64())
	}

	proofBuffer.ClearItems(batchIDs...)
	return nil
}
