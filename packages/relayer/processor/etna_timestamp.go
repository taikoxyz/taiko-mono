package processor

import (
	"context"
	"errors"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
)

// etnaTimestampCacheTTL is how long a read of the destination's Etna timestamp is reused. Every
// waiting message asks for it once per header-sync interval; the cache keeps that to one call
// per minute per process, and a later Anchor upgrade is still seen within a minute.
const etnaTimestampCacheTTL = time.Minute

// anchorCaller is the part of the destination chain's Anchor that the Etna proof path reads.
type anchorCaller interface {
	EtnaTimestamp(opts *bind.CallOpts) (uint64, error)
	GetL1StateRoot(opts *bind.CallOpts, blockId uint64) ([32]byte, error)
}

// etnaTimestampCache holds the last read of the destination's Etna timestamp.
type etnaTimestampCache struct {
	mu        sync.Mutex
	readAt    time.Time
	timestamp uint64
	supported bool
}

// etnaTimestamp returns the destination's Etna activation timestamp. supported is false when the
// destination has no such timestamp: the L1 Inbox of an L2→L1 processor, an Anchor not yet
// upgraded, or no Anchor configured. Both outcomes are cached for etnaTimestampCacheTTL; any other
// error is returned and not cached.
func (p *Processor) etnaTimestamp(ctx context.Context) (timestamp uint64, supported bool, err error) {
	if p.destAnchor == nil {
		return 0, false, nil
	}

	c := &p.etnaTimestamps

	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.readAt.IsZero() && p.currentTime().Sub(c.readAt) < etnaTimestampCacheTTL {
		return c.timestamp, c.supported, nil
	}

	timestamp, err = p.destAnchor.EtnaTimestamp(&bind.CallOpts{Context: ctx})

	switch {
	case err == nil:
		c.timestamp, c.supported = timestamp, true
	case isUnsupportedCallError(err):
		c.timestamp, c.supported = 0, false
	default:
		return 0, false, err
	}

	c.readAt = p.currentTime()

	return c.timestamp, c.supported, nil
}

// isUnsupportedCallError reports whether a contract call failed because the contract does not
// implement the function, rather than because the call could not be made.
func isUnsupportedCallError(err error) bool {
	return errors.Is(err, bind.ErrNoCode) || strings.Contains(err.Error(), "execution reverted")
}
