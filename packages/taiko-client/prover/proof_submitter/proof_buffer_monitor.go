package submitter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
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
	proofCacheMaps map[proofProducer.ProofType]cmap.ConcurrentMap[*big.Int, *proofProducer.ProofResponse],
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
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
	cacheMap cmap.ConcurrentMap[*big.Int, *proofProducer.ProofResponse],
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
			// remove stale cache
			removeFinalizedProofsFromCache(cacheMap, coreState.LastFinalizedProposalId)
			// flush cached proofs
			fromID := new(big.Int).SetUint64(buffer.LastInsertID())
			toID := new(big.Int).Add(fromID, new(big.Int).SetUint64(buffer.AvailableCapacity()))
			if err := flushProofCacheRange(fromID, toID, buffer, cacheMap); err != nil {
				if !errors.Is(err, ErrCacheNotFound) {
					log.Error(
						"Failed to flush proof cache range",
						"error", err,
						"fromID", fromID,
						"toID", toID,
					)
				}
			}
		}
	}
}

// removeFinalizedProofsFromCache deletes cached proofs whose IDs are finalized already.
func removeFinalizedProofsFromCache(
	cacheMap cmap.ConcurrentMap[*big.Int, *proofProducer.ProofResponse],
	lastFinalizedProposalID *big.Int,
) {
	if lastFinalizedProposalID == nil {
		return
	}

	for _, proposalID := range cacheMap.Keys() {
		if proposalID.Cmp(lastFinalizedProposalID) < 0 {
			cacheMap.Remove(proposalID)
		}
	}
}

// proofRangeCached reports whether every ID in [fromID, toID] exists in the proof cache.
func proofRangeCached(
	fromID, toID *big.Int,
	cacheMap cmap.ConcurrentMap[*big.Int, *proofProducer.ProofResponse],
) bool {
	if fromID.Cmp(toID) > 0 {
		return false
	}
	currentID := fromID
	for currentID.Cmp(toID) <= 0 {
		if _, ok := cacheMap.Get(currentID); !ok {
			return false
		}
		currentID = currentID.Add(currentID, common.Big1)
	}
	log.Info("Proof range cache hit", "fromID", fromID, "toID", toID)
	return true
}

// flushProofCacheRange drains cached proofs from fromID through toID into the proof buffer.
func flushProofCacheRange(
	fromID, toID *big.Int,
	proofBuffer *proofProducer.ProofBuffer,
	cacheMap cmap.ConcurrentMap[*big.Int, *proofProducer.ProofResponse],
) error {
	if proofBuffer == nil {
		return fmt.Errorf("invalid arguments when flushing proof cache range")
	}
	log.Info("Flushing proof cache range", "from", fromID, "to", toID)
	currentID := fromID
	for currentID.Cmp(toID) <= 0 {
		cachedProof, ok := cacheMap.Get(currentID)
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
		cacheMap.Remove(currentID)
		currentID = currentID.Add(currentID, common.Big1)
	}
	return nil
}
