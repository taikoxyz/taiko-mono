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
	proofCacheMaps map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse],
	flushCacheNotify chan proofProducer.ProofType,
) {
	log.Info("Starting proof cache cleanup and flushing monitors", "monitorInterval", monitorInterval)
	for proofType, cacheMap := range proofCacheMaps {
		go cleanUpStaleCacheAndFlush(ctx, rpc, cacheMap, monitorInterval, proofType, flushCacheNotify)
	}
}

// cleanUpStaleCacheAndFlush periodically removes cached proofs that have already been
// finalized so stale entries do not accumulate and flush cache into buffer.
func cleanUpStaleCacheAndFlush(
	ctx context.Context,
	rpc *rpc.Client,
	cacheMap cmap.ConcurrentMap[string, *proofProducer.ProofResponse],
	cleanUpInterval time.Duration,
	proofType proofProducer.ProofType,
	flushCacheNotify chan proofProducer.ProofType,
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
			flushCacheNotify <- proofType
		}
	}
}

// removeFinalizedProofsFromCache deletes cached proofs whose IDs are finalized already.
func removeFinalizedProofsFromCache(
	cacheMap cmap.ConcurrentMap[string, *proofProducer.ProofResponse],
	lastFinalizedProposalID *big.Int,
) {
	if lastFinalizedProposalID == nil {
		return
	}

	for _, proposalID := range cacheMap.Keys() {
		id, fail := new(big.Int).SetString(proposalID, 10)
		if fail {
			return
		}
		if id.Cmp(lastFinalizedProposalID) <= 0 {
			log.Info("Removing finalized proof from cache", "proposalID", proposalID)
			cacheMap.Remove(proposalID)
		}
	}
}

// flushProofCacheRange drains cached proofs from fromID through toID into the proof buffer.
func flushProofCacheRange(
	fromID, toID *big.Int,
	proofBuffer *proofProducer.ProofBuffer,
	cacheMap cmap.ConcurrentMap[string, *proofProducer.ProofResponse],
) error {
	if proofBuffer == nil {
		return fmt.Errorf("invalid arguments when flushing proof cache range")
	}
	log.Info("Flushing proof cache range", "from", fromID, "to", toID)
	currentID := fromID
	for currentID.Cmp(toID) <= 0 {
		cachedProof, ok := cacheMap.Get(currentID.String())
		log.Info("Getting cached proof", "id", currentID, "cachedProof", cachedProof, "ok", ok)
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
		currentID = new(big.Int).Add(currentID, common.Big1)
	}
	return nil
}
