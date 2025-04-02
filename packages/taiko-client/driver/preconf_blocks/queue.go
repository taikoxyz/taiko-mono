package preconfblocks

import (
	"sync"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
)

// maxTrackedPayloads is the maximum number of prepared payloads the execution
// engine tracks before evicting old ones. Ideally we should only ever track the
// latest one; but have a slight wiggle room for non-ideal conditions.
const maxTrackedPayloads = 768

// payloadQueueItem represents an id->payload tuple to store until it's retrieved
// or evicted.
type payloadQueueItem struct {
	id      uint64
	payload *eth.ExecutionPayload
}

// payloadQueue tracks the latest handful of constructed payloads to be retrieved
// by the beacon chain if block production is requested.
type payloadQueue struct {
	payloads []*payloadQueueItem
	lock     sync.RWMutex
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
