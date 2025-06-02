package preconfblocks

import (
	"slices"
	"sync"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

// maxTrackedPayloads is the maximum number of prepared payloads the execution
// engine tracks before evicting old ones.
const maxTrackedPayloads = 768 // equal to `maxBlocksPerBatch`

// payloadQueueItem represents an id->payload tuple to store until it's retrieved
// or evicted.
type payloadQueueItem struct {
	id      uint64
	payload *eth.ExecutionPayload
}

// payloadQueue tracks the latest payloads from the P2P gossip messages.
type payloadQueue struct {
	payloads    []*payloadQueueItem
	totalCached uint64
	lock        sync.RWMutex
}

// newPayloadQueue creates a pre-initialized queue with a fixed number of slots
// all containing empty items.
func newPayloadQueue() *payloadQueue {
	return &payloadQueue{
		payloads: make([]*payloadQueueItem, maxTrackedPayloads),
	}
}

// put inserts a new payload into the queue at the given id.
func (q *payloadQueue) put(id uint64, payload *eth.ExecutionPayload) {
	q.lock.Lock()
	defer q.lock.Unlock()

	copy(q.payloads[1:], q.payloads)
	q.payloads[0] = &payloadQueueItem{
		id:      id,
		payload: payload,
	}
	q.totalCached++
	metrics.DriverPreconfEnvelopeCachedCounter.Inc()
}

// get retrieves a previously stored payload item or nil if it does not exist.
func (q *payloadQueue) get(id uint64, hash common.Hash) *eth.ExecutionPayload {
	q.lock.RLock()
	defer q.lock.RUnlock()

	for _, item := range q.payloads {
		if item == nil {
			return nil // no more items
		}
		if item.id == id && item.payload.BlockHash == hash {
			return item.payload
		}
	}
	return nil
}

// getChildren retrieves the longest previously stored payload items that are children of the
// given parent payload.
func (q *payloadQueue) getChildren(parentID uint64, parentHash common.Hash) []*eth.ExecutionPayload {
	q.lock.RLock()
	defer q.lock.RUnlock()

	longestChildren := []*eth.ExecutionPayload{}

	var searchLongestChildren func(currentPayload *eth.ExecutionPayload, chain []*eth.ExecutionPayload)
	searchLongestChildren = func(currentpayload *eth.ExecutionPayload, chain []*eth.ExecutionPayload) {
		children := []*eth.ExecutionPayload{}
		for _, item := range q.payloads {
			if item == nil {
				break // no more items
			}
			if item.id == uint64(currentpayload.BlockNumber)+1 && item.payload.ParentHash == currentpayload.BlockHash {
				children = append(children, item.payload)
			}
		}
		if len(children) == 0 {
			if len(chain) > len(longestChildren) {
				longestChildren = slices.Clone(chain)
			}
			return
		}

		for _, child := range children {
			searchLongestChildren(child, append(chain, child))
		}
	}

	searchLongestChildren(&eth.ExecutionPayload{
		BlockNumber: eth.Uint64Quantity(parentID),
		BlockHash:   parentHash,
	}, []*eth.ExecutionPayload{})

	return longestChildren
}

// has checks if a particular payload is already tracked.
func (q *payloadQueue) has(id uint64, hash common.Hash) bool {
	q.lock.RLock()
	defer q.lock.RUnlock()

	for _, item := range q.payloads {
		if item == nil {
			return false
		}
		if item.id == id && item.payload.BlockHash == hash {
			return true
		}
	}
	return false
}

// getLatestPayload retrieves the latest payload stored in the queue.
func (q *payloadQueue) getLatestPayload() *eth.ExecutionPayload {
	q.lock.RLock()
	defer q.lock.RUnlock()

	if q.payloads[0] == nil {
		return nil
	}

	return q.payloads[0].payload
}

// getTotalCached retrieves the total number of cached payloads after the initialization of the queue.
func (q *payloadQueue) getTotalCached() uint64 {
	q.lock.RLock()
	defer q.lock.RUnlock()

	return q.totalCached
}
