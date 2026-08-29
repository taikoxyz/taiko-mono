package utils

import (
	"context"
	"log/slog"
	"strconv"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// DefaultPrivateRPCRetryInterval is how long a private endpoint stays out of rotation once it has
// been tripped.
const DefaultPrivateRPCRetryInterval = 5 * time.Minute

// DefaultPrivateRPCFailureThreshold is how many consecutive failures take a private endpoint out of
// rotation.
//
// One failure is not enough. A relay that drops a single transaction — because that transaction
// would revert, say, which is what happens when a competitor already claimed the message — is still
// healthy for every other message. Tripping on it would route unrelated claims through the public
// mempool, which is the thing this is meant to avoid.
const DefaultPrivateRPCFailureThreshold = 3

// TxSender hands a signed transaction to one endpoint. *ethclient.Client satisfies it.
type TxSender interface {
	SendTransaction(ctx context.Context, tx *types.Transaction) error
}

// SendingBackend is a txmgr.ETHBackend that answers every read from the chain's own endpoint while
// handing signed transactions to endpoints that do not gossip them.
//
// processMessage is permissionless and pays its fee to whoever lands it first, so a transaction
// waiting in the public mempool hands competitors the message and proof they need to take that fee,
// leaving this relayer to pay gas for a call that then reverts. Only the broadcast has to be
// private, and keeping it to the broadcast matters: nonces, gas prices and receipts all still come
// from our own node, so the single transaction manager above this keeps one nonce source and the
// relayer's reads do not depend on a relay's availability or rate limits.
//
// Private endpoints are tried in the order they were configured, within one send: it is the same
// signed transaction each time, so offering it to a second relay after the first errored is
// idempotent — at most one of them can land it. An endpoint that fails the failure threshold times
// in a row drops out of rotation for the retry interval, and a landed transaction clears its tally
// and re-admits it. Only when no private endpoint is left in rotation does a transaction go out
// through the public endpoint.
type SendingBackend struct {
	// ETHBackend serves every read, and sends when no private endpoint is in rotation.
	txmgr.ETHBackend

	private          []TxSender
	failures         []int
	failedAt         []time.Time
	failureThreshold int
	retryInterval    time.Duration
	now              func() time.Time
	mu               sync.Mutex
}

// NewSendingBackend wraps public so that sends are routed through private, in priority order.
// private may be empty, in which case every send goes through public unchanged. A nil or
// non-positive retryInterval means DefaultPrivateRPCRetryInterval.
func NewSendingBackend(
	public txmgr.ETHBackend,
	private []TxSender,
	retryInterval *time.Duration,
) *SendingBackend {
	interval := DefaultPrivateRPCRetryInterval
	if retryInterval != nil && *retryInterval > 0 {
		interval = *retryInterval
	}

	return &SendingBackend{
		ETHBackend:       public,
		private:          private,
		failures:         make([]int, len(private)),
		failedAt:         make([]time.Time, len(private)),
		failureThreshold: DefaultPrivateRPCFailureThreshold,
		retryInterval:    interval,
		now:              time.Now,
	}
}

// SendTransaction offers tx to each private endpoint still in rotation, in order, and falls back to
// the public endpoint only once none is left. It reports the last error when every endpoint in
// rotation refused it, leaving the transaction manager above to bump and retry.
func (b *SendingBackend) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	inRotation := b.inRotation()

	if len(inRotation) == 0 {
		if len(b.private) != 0 {
			// Private endpoints are configured but none is usable, so this claim and its proof are
			// about to reach the public mempool. That is the exposure this is meant to remove, so
			// it is worth alerting on rather than degrading quietly.
			relayer.PrivateRPCUnavailable.Inc()

			slog.Warn("No private endpoint in rotation, broadcasting publicly",
				"txHash", tx.Hash().Hex(),
			)
		}

		return b.ETHBackend.SendTransaction(ctx, tx)
	}

	var err error

	for _, i := range inRotation {
		if err = b.private[i].SendTransaction(ctx, tx); err == nil {
			b.recordSuccess(i)

			return nil
		}

		b.recordFailure(i)
		relayer.PrivateRPCFailures.WithLabelValues(strconv.Itoa(i)).Inc()

		slog.Warn("Private endpoint refused a transaction",
			"endpoint", i,
			"txHash", tx.Hash().Hex(),
			"error", err.Error(),
		)
	}

	return err
}

// Close closes the public backend and every private endpoint.
func (b *SendingBackend) Close() {
	b.ETHBackend.Close()

	for _, sender := range b.private {
		if closer, ok := sender.(interface{ Close() }); ok {
			closer.Close()
		}
	}
}

// NumPrivateEndpoints returns how many private endpoints the backend was configured with.
func (b *SendingBackend) NumPrivateEndpoints() int {
	return len(b.private)
}

// inRotation returns the indices of the private endpoints currently usable, in priority order,
// re-admitting any whose retry interval has elapsed.
func (b *SendingBackend) inRotation() []int {
	b.mu.Lock()
	defer b.mu.Unlock()

	now := b.now()
	indices := make([]int, 0, len(b.private))

	for i := range b.private {
		if !b.failedAt[i].IsZero() {
			if now.Sub(b.failedAt[i]) < b.retryInterval {
				continue
			}

			// Back from a trip with a fresh budget, rather than the spent one that would trip it
			// again on its first failure.
			b.failedAt[i] = time.Time{}
			b.failures[i] = 0
		}

		indices = append(indices, i)
	}

	return indices
}

// recordFailure counts a refused send against the endpoint at index, taking it out of rotation once
// it has refused failureThreshold sends in a row.
func (b *SendingBackend) recordFailure(index int) {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.failures[index]++

	if b.failures[index] >= b.failureThreshold {
		b.failedAt[index] = b.now()
	}
}

// recordSuccess returns the endpoint at index to full health. Only consecutive failures trip an
// endpoint, so one transaction it would not take does not cost it its turn, and an endpoint that
// just took one is not down whatever its recent record.
func (b *SendingBackend) recordSuccess(index int) {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.failures[index] = 0
	b.failedAt[index] = time.Time{}
}
