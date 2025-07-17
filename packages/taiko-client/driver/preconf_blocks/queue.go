package preconfblocks

import (
	"slices"
	"sync"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
)

// maxTrackedPayloads is the maximum number of prepared payloads the execution
// engine tracks before evicting old ones.
const maxTrackedPayloads = 768 // equal to `maxBlocksPerBatch`

// payloadQueueItem represents an id->envelope tuple to store until it's retrieved
// or evicted.
type payloadQueueItem struct {
	id       uint64
	envelope *preconf.Envelope
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

// put inserts a new payload item into the queue at the given id.
func (q *payloadQueue) put(id uint64, envelope *preconf.Envelope) {
	q.lock.Lock()
	defer q.lock.Unlock()

	copy(q.payloads[1:], q.payloads)
	q.payloads[0] = &payloadQueueItem{
		id:       id,
		envelope: envelope,
	}
	q.totalCached++
	metrics.DriverPreconfEnvelopeCachedCounter.Inc()
}

// get retrieves a previously stored payload item or nil if it does not exist.
func (q *payloadQueue) get(id uint64, hash common.Hash) *preconf.Envelope {
	q.lock.RLock()
	defer q.lock.RUnlock()

	for _, item := range q.payloads {
		if item == nil {
			return nil // no more items
		}
		if item.id == id && item.envelope.Payload.BlockHash == hash {
			return item.envelope
		}
	}
	return nil
}

// getChildren retrieves the longest previously stored payload items that are children of the
// given parent payload.
func (q *payloadQueue) getChildren(parentID uint64, parentHash common.Hash) []*preconf.Envelope {
	q.lock.RLock()
	defer q.lock.RUnlock()

	longestChildren := []*preconf.Envelope{}

	var searchLongestChildren func(currentPayload *preconf.Envelope, chain []*preconf.Envelope)
	searchLongestChildren = func(currentpayload *preconf.Envelope, chain []*preconf.Envelope) {
		children := []*preconf.Envelope{}
		for _, item := range q.payloads {
			if item == nil {
				break // no more items
			}
			if item.id == uint64(currentpayload.Payload.BlockNumber)+1 &&
				item.envelope.Payload.ParentHash == currentpayload.Payload.BlockHash {
				children = append(children, item.envelope)
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

	searchLongestChildren(&preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(parentID),
			BlockHash:   parentHash,
		},
	}, []*preconf.Envelope{})

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
		if item.id == id && item.envelope.Payload.BlockHash == hash {
			return true
		}
	}
	return false
}

// getLatestPayload retrieves the latest payload stored in the queue.
func (q *payloadQueue) getLatestPayload() *preconf.Envelope {
	q.lock.RLock()
	defer q.lock.RUnlock()

	if q.payloads[0] == nil {
		return nil
	}

	return q.payloads[0].envelope
}

// getTotalCached retrieves the total number of cached payloads after the initialization of the queue.
func (q *payloadQueue) getTotalCached() uint64 {
	q.lock.RLock()
	defer q.lock.RUnlock()

	return q.totalCached
}
