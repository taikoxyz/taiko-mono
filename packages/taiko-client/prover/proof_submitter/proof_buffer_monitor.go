package submitter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

const monitorInterval = 5 * time.Minute

// startProofBufferMonitors launches a monitor goroutine per proof type so we can
// enforce forced aggregation deadlines in the background.
func startProofBufferMonitors(
	ctx context.Context,
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
	tryAggregate func(*proofProducer.ProofBuffer, proofProducer.ProofType) bool,
) {
	log.Info("Starting proof buffers monitors", "monitorInterval", monitorInterval)
	for proofType, buffer := range proofBuffers {
		go monitorProofBuffer(ctx, proofType, buffer, monitorInterval, tryAggregate)
	}
}

// monitorProofBuffer periodically attempts aggregation for a single proof
// buffer until the context is canceled.
func monitorProofBuffer(
	ctx context.Context,
	proofType proofProducer.ProofType,
	buffer *proofProducer.ProofBuffer,
	monitorInterval time.Duration,
	tryAggregate func(*proofProducer.ProofBuffer, proofProducer.ProofType) bool,
) {
	if tryAggregate == nil {
		return
	}
	ticker := time.NewTicker(monitorInterval)
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

// startCacheCleanUp launches goroutines that keep cache maps pruned from
// already-finalized proposal IDs.
func startCacheCleanUp(
	ctx context.Context,
	rpc *rpc.Client,
	proofCacheMaps map[proofProducer.ProofType]map[uint64]*proofProducer.ProofResponse,
) {
	log.Info("Starting proof cache cleanup monitors", "monitorInterval", monitorInterval)
	for _, cacheMap := range proofCacheMaps {
		go cleanUpStaleCache(ctx, rpc, cacheMap, monitorInterval)
	}
}

// cleanUpStaleCache periodically removes cached proofs that have already been
// finalized so stale entries do not accumulate.
func cleanUpStaleCache(
	ctx context.Context,
	rpc *rpc.Client,
	cacheMap map[uint64]*proofProducer.ProofResponse,
	cleanUpInterval time.Duration,
) {
	ticker := time.NewTicker(cleanUpInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Debug("context of proof cache cleanup monitor is done")
			return
		case <-ticker.C:
			coreState, err := rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
			if err != nil {
				log.Error("Failed to get Shasta core state", "error", err)
				return
			}
			lastFinalizedProposalID := coreState.LastFinalizedProposalId
			removeFinalizedProofsFromCache(cacheMap, lastFinalizedProposalID)
		}
	}
}

// removeFinalizedProofsFromCache deletes cached proofs whose IDs are finalized already.
func removeFinalizedProofsFromCache(
	cacheMap map[uint64]*proofProducer.ProofResponse,
	lastFinalizedProposalID *big.Int,
) {
	if cacheMap == nil || lastFinalizedProposalID == nil {
		return
	}
	for proposalID := range cacheMap {
		if proposalID < lastFinalizedProposalID.Uint64() {
			delete(cacheMap, proposalID)
		}
	}
}

// proofRangeCached reports whether every ID in [fromID, toID] exists in the proof cache.
func proofRangeCached(
	fromID, toID uint64,
	cacheMap map[uint64]*proofProducer.ProofResponse,
) bool {
	if cacheMap == nil || fromID > toID {
		return false
	}
	currentID := fromID
	for currentID <= toID {
		if _, ok := cacheMap[currentID]; !ok {
			return false
		}
		currentID++
	}
	return true
}

// flushProofCacheRange drains cached proofs from fromID through toID into the proof buffer.
func flushProofCacheRange(
	fromID, toID uint64,
	proofBuffer *proofProducer.ProofBuffer,
	cacheMap map[uint64]*proofProducer.ProofResponse,
	tryAggregate func(*proofProducer.ProofBuffer, proofProducer.ProofType) bool,
) error {
	if proofBuffer == nil {
		return fmt.Errorf("invalid arguments when flushing proof cache range")
	}
	currentID := fromID
	for currentID <= toID {
		cachedProof, ok := cacheMap[currentID]
		if !ok {
			return fmt.Errorf("cached proof not found for proposal %d", currentID)
		}
		if _, err := proofBuffer.Write(cachedProof); err != nil {
			if errors.Is(err, proofProducer.ErrBufferOverflow) {
				log.Info("")
				tryAggregate(proofBuffer, cachedProof.ProofType)
				return nil
			}
			return err
		}
		delete(cacheMap, currentID)
		currentID++
	}
	return nil
}
