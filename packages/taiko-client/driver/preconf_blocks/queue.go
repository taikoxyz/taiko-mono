package preconfblocks

import (
	"slices"
	"sync"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
)

// maxTrackedPayloads is the maximum number of prepared envelopes the execution
// engine tracks before evicting old ones.
const maxTrackedPayloads = 768 // equal to `maxBlocksPerBatch`

// envelopeQueueItem represents an id->envelope tuple to store until it's retrieved
// or evicted.
type envelopeQueueItem struct {
	id       uint64
	envelope *preconf.Envelope
}

// envelopeQueue tracks the latest envelopes from the P2P gossip messages.
type envelopeQueue struct {
	envelopes   []*envelopeQueueItem
	totalCached uint64
	lock        sync.RWMutex
}

// newEnvelopeQueue creates a pre-initialized queue with a fixed number of slots
// all containing empty items.
func newEnvelopeQueue() *envelopeQueue {
	return &envelopeQueue{
		envelopes: make([]*envelopeQueueItem, maxTrackedPayloads),
	}
}

// put inserts a new envelope item into the queue at the given id.
func (q *envelopeQueue) put(id uint64, envelope *preconf.Envelope) {
	q.lock.Lock()
	defer q.lock.Unlock()

	copy(q.envelopes[1:], q.envelopes)
	q.envelopes[0] = &envelopeQueueItem{
		id:       id,
		envelope: envelope,
	}
	q.totalCached++
	metrics.DriverPreconfEnvelopeCachedCounter.Inc()
}

// get retrieves a previously stored envelope item or nil if it does not exist.
func (q *envelopeQueue) get(id uint64, hash common.Hash) *preconf.Envelope {
	q.lock.RLock()
	defer q.lock.RUnlock()

	for _, item := range q.envelopes {
		if item == nil {
			return nil // no more items
		}
		if item.id == id && item.envelope.Payload.BlockHash == hash {
			return item.envelope
		}
	}
	return nil
}

// getChildren retrieves the longest previously stored envelope items that are children of the
// given parent envelope.
func (q *envelopeQueue) getChildren(parentID uint64, parentHash common.Hash) []*preconf.Envelope {
	q.lock.RLock()
	defer q.lock.RUnlock()

	longestChildren := []*preconf.Envelope{}

	var searchLongestChildren func(currentPayload *preconf.Envelope, chain []*preconf.Envelope)
	searchLongestChildren = func(currentpayload *preconf.Envelope, chain []*preconf.Envelope) {
		children := []*preconf.Envelope{}
		for _, item := range q.envelopes {
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

// hasExact checks if a particular envelope (by id and hash) is already tracked.
func (q *envelopeQueue) hasExact(id uint64, hash common.Hash) bool {
	q.lock.RLock()
	defer q.lock.RUnlock()

	for _, item := range q.envelopes {
		if item == nil {
			return false
		}
		if item.id == id && item.envelope.Payload.BlockHash == hash {
			return true
		}
	}
	return false
}

// getLatestEnvelope retrieves the latest envelope stored in the queue.
func (q *envelopeQueue) getLatestEnvelope() *preconf.Envelope {
	q.lock.RLock()
	defer q.lock.RUnlock()

	if q.envelopes[0] == nil {
		return nil
	}

	return q.envelopes[0].envelope
}

// getTotalCached retrieves the total number of cached envelopes after the initialization of the queue.
func (q *envelopeQueue) getTotalCached() uint64 {
	q.lock.RLock()
	defer q.lock.RUnlock()

	return q.totalCached
}
