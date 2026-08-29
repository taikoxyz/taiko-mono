package utils

import (
	"context"
	"log/slog"
	"regexp"
	"strconv"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// DefaultPrivateRPCRetryInterval is how long a private endpoint stays out of rotation once it has
// been tripped.
const DefaultPrivateRPCRetryInterval = 5 * time.Minute

// DefaultPrivateRPCFailureThreshold is how many consecutive transactions an endpoint has to refuse
// before it is taken out of rotation.
//
// One is not enough. A relay that drops a single transaction — because that transaction would
// revert, say, which is what happens when a competitor already claimed the message — is still
// healthy for every other message. Tripping on it would route unrelated claims through the public
// mempool, which is the thing this is meant to avoid.
//
// The transactions also have to be distinct; see recordFailure.
const DefaultPrivateRPCFailureThreshold = 3

// urlInErrorText matches a URL inside an error message, so it can be kept out of the logs.
var urlInErrorText = regexp.MustCompile(`[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s"]*`)

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
	lastCharged      []common.Hash
	failureThreshold int
	retryInterval    time.Duration
	now              func() time.Time
	mu               sync.Mutex
	closeOnce        sync.Once
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
		lastCharged:      make([]common.Hash, len(private)),
		failureThreshold: DefaultPrivateRPCFailureThreshold,
		retryInterval:    interval,
		now:              time.Now,
	}
}

// SendTransaction offers tx to each private endpoint still in rotation, in order, and falls back to
// the public endpoint only once none is left. It reports the last error when every endpoint in
// rotation refused it, leaving the transaction manager above to bump and retry.
//
// Each endpoint is given its own share of the time left on ctx. The transaction manager calls this
// under its network timeout, so without that an endpoint which accepts the connection and then
// never answers would spend the whole budget: every endpoint behind it would be handed an expired
// context, fail instantly, and be counted as failing, which is how the failover for the outage
// mode it matters most for would take the healthy relays down with it.
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

	for attempt, i := range inRotation {
		attemptCtx, cancel := attemptContext(ctx, len(inRotation)-attempt)
		err = b.private[i].SendTransaction(attemptCtx, tx)

		cancel()

		if err == nil {
			b.recordSuccess(i)

			return nil
		}

		if ctx.Err() != nil {
			// Our own deadline ran out, not this endpoint's. Counting it, or offering the
			// transaction to the endpoints behind it on a context they cannot use, would trip
			// relays that were never given a send.
			return err
		}

		b.recordFailure(i, tx.Hash())
		relayer.PrivateRPCFailures.WithLabelValues(strconv.Itoa(i)).Inc()

		slog.Warn("Private endpoint refused a transaction",
			"endpoint", i,
			"txHash", tx.Hash().Hex(),
			"error", redactURLs(err),
		)
	}

	return err
}

// attemptContext gives one endpoint its share of the time left on ctx, so an endpoint that hangs
// cannot spend the budget the remaining endpoints need. The share is computed per attempt rather
// than once up front, so an endpoint that fails fast leaves the rest of its share to the next one,
// and the last endpoint gets everything that is left. A ctx with no deadline is passed through.
func attemptContext(ctx context.Context, remaining int) (context.Context, context.CancelFunc) {
	deadline, ok := ctx.Deadline()
	if !ok || remaining <= 1 {
		return context.WithCancel(ctx)
	}

	return context.WithTimeout(ctx, time.Until(deadline)/time.Duration(remaining))
}

// redactURLs removes endpoints from an error's text. Transport errors quote the URL they were
// dialling, which can carry an API key in its path or query; the endpoint's position is logged
// alongside, and that is what identifies the relay without publishing a credential.
func redactURLs(err error) string {
	return urlInErrorText.ReplaceAllString(err.Error(), "[redacted]")
}

// Close closes the public backend and every private endpoint. The transaction manager closes its
// backend on shutdown and the processor closes it too, so this has to be safe to call twice.
func (b *SendingBackend) Close() {
	b.closeOnce.Do(func() {
		b.ETHBackend.Close()

		for _, sender := range b.private {
			if closer, ok := sender.(interface{ Close() }); ok {
				closer.Close()
			}
		}
	})
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
			b.lastCharged[i] = common.Hash{}
		}

		indices = append(indices, i)
	}

	return indices
}

// recordFailure counts a refused transaction against the endpoint at index, taking it out of
// rotation once it has refused failureThreshold distinct transactions in a row.
//
// Refusing the same transaction again is not counted. A relay that will not take one particular
// claim — one that would revert because a competitor already processed the message — looks exactly
// like a relay that is down if you only count errors, and the transaction manager resubmits the
// same transaction repeatedly, so one such claim could spend the whole budget on its own. Requiring
// distinct transactions separates the two without having to classify error strings: an endpoint
// that is genuinely down refuses whatever it is handed, so it still trips.
func (b *SendingBackend) recordFailure(index int, txHash common.Hash) {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.failures[index] > 0 && b.lastCharged[index] == txHash {
		return
	}

	b.lastCharged[index] = txHash
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
	b.lastCharged[index] = common.Hash{}
}
