package submitter

import (
	"context"
	"github.com/ethereum/go-ethereum/log"
	"time"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// startProofBufferMonitors launches a monitor goroutine per proof type so we can
// enforce forced aggregation deadlines in the background.
func startProofBufferMonitors(
	ctx context.Context,
	forceBatchProvingInterval time.Duration,
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
	tryAggregate func(*proofProducer.ProofBuffer, proofProducer.ProofType) bool,
) {
	if forceBatchProvingInterval <= 0 {
		return
	}

	for proofType, buffer := range proofBuffers {
		go monitorProofBuffer(ctx, proofType, buffer, forceBatchProvingInterval, tryAggregate)
	}
}

// monitorProofBuffer periodically attempts aggregation for a single proof
// buffer until the context is canceled.
func monitorProofBuffer(
	ctx context.Context,
	proofType proofProducer.ProofType,
	buffer *proofProducer.ProofBuffer,
	forceBatchProvingInterval time.Duration,
	tryAggregate func(*proofProducer.ProofBuffer, proofProducer.ProofType) bool,
) {
	if tryAggregate == nil {
		return
	}
	ticker := time.NewTicker(forceBatchProvingInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Debug("context of proof buffer monitor is done")
			return
		case <-ticker.C:
			tryAggregate(buffer, proofType)
		}
	}
}
