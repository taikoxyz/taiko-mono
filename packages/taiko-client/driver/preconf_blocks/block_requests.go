package preconfblocks

import (
	"time"

	"github.com/ethereum/go-ethereum/common"
)

// blockRequestCooldown is the minimum time between two backfill requests for the same missing
// parent hash. It matches the Rust driver's DEFAULT_REQUEST_COOLDOWN_SECS so both
// implementations retry on the same schedule.
const blockRequestCooldown = 10 * time.Second

// blockRequestTracker decides when a missing parent hash may be requested from the P2P
// network again.
//
// Suppression is keyed on time, never on a publish having succeeded: PublishL2Request is a
// bare gossipsub topic publish that returns nil as soon as the message reaches the router,
// with or without a single mesh peer, so its error carries no delivery information. A request
// that is never answered is therefore retried once the cooldown elapses, and only an answer
// clears it for good.
//
// It is not safe for concurrent use: every caller reaches it from a P2P handler holding the
// server's mutex.
type blockRequestTracker struct {
	cooldown    time.Duration
	requestedAt map[common.Hash]time.Time
}

// newBlockRequestTracker creates a tracker with the given per-hash cooldown.
func newBlockRequestTracker(cooldown time.Duration) *blockRequestTracker {
	return &blockRequestTracker{cooldown: cooldown, requestedAt: make(map[common.Hash]time.Time)}
}

// shouldRequest reports whether the given hash may be requested at `now`, either because it
// has never been requested or because its cooldown has elapsed. It does not record the
// request: callers that decide not to publish must leave the window untouched so the next
// attempt is immediate.
func (t *blockRequestTracker) shouldRequest(hash common.Hash, now time.Time) bool {
	// pruneExpired has just dropped every entry past its cooldown, so a surviving entry is one
	// still inside its window.
	t.pruneExpired(now)

	_, suppressed := t.requestedAt[hash]
	return !suppressed
}

// markPublished records that a request for the given hash has just been published, suppressing
// further requests for one cooldown window.
func (t *blockRequestTracker) markPublished(hash common.Hash, now time.Time) {
	t.requestedAt[hash] = now
}

// markAnswered clears the hash, so a later request for it is not made to wait out a cooldown
// window it no longer needs.
func (t *blockRequestTracker) markAnswered(hash common.Hash) {
	delete(t.requestedAt, hash)
}

// pruneExpired drops entries whose cooldown has elapsed, keeping the map bounded by the number
// of hashes requested within one cooldown window rather than by the lifetime of the process.
func (t *blockRequestTracker) pruneExpired(now time.Time) {
	for hash, last := range t.requestedAt {
		if now.Sub(last) >= t.cooldown {
			delete(t.requestedAt, hash)
		}
	}
}
