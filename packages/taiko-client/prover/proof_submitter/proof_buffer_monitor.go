package submitter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"

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

// startCacheCleanUpAndFlush launches goroutines that keep cache maps pruned from
// already-finalized proposal IDs and flush cache into buffers.
func startCacheCleanUpAndFlush(
	ctx context.Context,
	rpc *rpc.Client,
	proofCacheMaps map[proofProducer.ProofType]*cmap.ConcurrentMap[uint64, *proofProducer.ProofResponse],
	proofBuffers cmap.ConcurrentMap[uint64, *proofProducer.ProofResponse],
) {
	log.Info("Starting proof cache cleanup and flushing monitors", "monitorInterval", monitorInterval)
	for proofType, cacheMap := range proofCacheMaps {
		buffer, ok := proofBuffers[proofType]
		if !ok {
			log.Error("Proof buffer for proof type not found", "proofType", proofType)
			return
		}
		go cleanUpStaleCacheAndFlush(ctx, rpc, cacheMap, monitorInterval, buffer)
	}
}

// cleanUpStaleCacheAndFlush periodically removes cached proofs that have already been
// finalized so stale entries do not accumulate and flush cache into buffer.
func cleanUpStaleCacheAndFlush(
	ctx context.Context,
	rpc *rpc.Client,
	cacheMap *ProofCache,
	cleanUpInterval time.Duration,
	buffer *proofProducer.ProofBuffer,
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
				continue // Skip this iteration, retry on next tick
			}
			lastFinalizedProposalID := coreState.LastFinalizedProposalId
			// remove stale cache
			removeFinalizedProofsFromCache(cacheMap, lastFinalizedProposalID)
			// flush cached proofs
			toID := lastFinalizedProposalID.Uint64() + buffer.MaxLength
			if err := flushProofCacheRange(lastFinalizedProposalID.Uint64(), toID, buffer, cacheMap); err != nil {
				if !errors.Is(err, ErrCacheNotFound) {
					log.Error(
						"Failed to flush proof cache range",
						"error", err,
						"fromID", lastFinalizedProposalID,
						"toID", toID,
					)
				}
			}
		}
	}
}

// removeFinalizedProofsFromCache deletes cached proofs whose IDs are finalized already.
func removeFinalizedProofsFromCache(
	cacheMap *ProofCache,
	lastFinalizedProposalID *big.Int,
) {
	if cacheMap == nil || lastFinalizedProposalID == nil {
		return
	}
	cacheMap.mu.Lock()
	defer cacheMap.mu.Unlock()
	for proposalID := range cacheMap.cache {
		if proposalID < lastFinalizedProposalID.Uint64() {
			delete(cacheMap.cache, proposalID)
		}
	}
}

// proofRangeCached reports whether every ID in [fromID, toID] exists in the proof cache.
func proofRangeCached(
	fromID, toID uint64,
	cacheMap *ProofCache,
) bool {
	if cacheMap == nil || fromID > toID {
		return false
	}
	cacheMap.mu.RLock()
	defer cacheMap.mu.RUnlock()
	currentID := fromID
	for currentID <= toID {
		if _, ok := cacheMap.cache[currentID]; !ok {
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
	cacheMap *ProofCache,
) error {
	if proofBuffer == nil || cacheMap == nil {
		return fmt.Errorf("invalid arguments when flushing proof cache range")
	}
	currentID := fromID
	cacheMap.mu.Lock()
	defer cacheMap.mu.Unlock()
	for currentID <= toID {
		cachedProof, ok := cacheMap.cache[currentID]
		if !ok {
			log.Error("cached proof not found for proposal", "proposalID", currentID)
			return ErrCacheNotFound
		}
		if _, err := proofBuffer.Write(cachedProof); err != nil {
			if errors.Is(err, proofProducer.ErrBufferOverflow) {
				log.Info(
					"Buffer overflow during cache flush, stop flushing",
					"proposalID", currentID,
					"proofType", cachedProof.ProofType,
				)
				return nil
			}
			return err
		}
		delete(cacheMap.cache, currentID)
		currentID++
	}
	return nil
}
