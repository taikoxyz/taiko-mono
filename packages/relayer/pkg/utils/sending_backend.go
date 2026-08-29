package utils

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"regexp"
	"strconv"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rpc"

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

// DefaultPrivateRPCAttemptTimeout caps a single attempt when the caller supplied no deadline.
//
// The transaction manager always calls SendTransaction under its NetworkTimeout, so this does not
// apply in the processor. It keeps the guarantee that one hanging endpoint cannot starve the ones
// behind it from depending on the caller.
const DefaultPrivateRPCAttemptTimeout = 30 * time.Second

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
// idempotent — at most one of them can land it. An endpoint that refuses the failure threshold of
// distinct transactions in a row drops out of rotation for the retry interval, and a landed
// transaction clears its tally and re-admits it. Only when no private endpoint is left in rotation
// does a transaction go out through the public endpoint.
type SendingBackend struct {
	// ETHBackend serves every read, and sends when no private endpoint is in rotation.
	txmgr.ETHBackend

	private          []TxSender
	failures         []int
	failedAt         []time.Time
	lastCharged      []common.Hash
	acceptedNonce    []uint64
	hasAccepted      []bool
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
		acceptedNonce:    make([]uint64, len(private)),
		hasAccepted:      make([]bool, len(private)),
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

		// DEST_RPC_URL can carry an API key too, so the public path is redacted the same way.
		return redacted(b.ETHBackend.SendTransaction(ctx, tx))
	}

	inRotation = b.deprioritiseAlreadyAccepted(inRotation, tx.Nonce())

	var err error

	for attempt, i := range inRotation {
		if ctxErr := ctx.Err(); ctxErr != nil {
			// Our own budget is gone before this endpoint was reached, so it never got a send.
			// Charging it, or handing it a context it cannot use, would trip relays that were
			// never tried. The endpoints already tried keep the failures they earned.
			if err == nil {
				err = ctxErr
			}

			return redacted(err)
		}

		attemptCtx, cancel := attemptContext(ctx, len(inRotation)-attempt)
		err = b.private[i].SendTransaction(attemptCtx, tx)

		cancel()

		if err == nil {
			b.recordSuccess(i, tx.Nonce())

			return nil
		}

		// The endpoint had a usable context and still did not take the transaction. That counts
		// against it whether it refused outright or spent its whole share without answering:
		// hanging is the outage mode this is most meant to survive, so an endpoint that hangs has
		// to be able to trip. Checking the deadline before the send rather than after is what
		// keeps that true for the last endpoint in rotation, whose share is the rest of the
		// budget and which therefore always finds ctx expired once it has hung.
		b.recordFailure(i, tx.Hash(), answeredWithRejection(err))
		relayer.PrivateRPCFailures.WithLabelValues(strconv.Itoa(i)).Inc()

		slog.Warn("Private endpoint refused a transaction",
			"endpoint", i,
			"txHash", tx.Hash().Hex(),
			"error", redactURLs(err),
		)
	}

	return redacted(err)
}

// attemptContext gives one endpoint its share of the time left on ctx, so an endpoint that hangs
// cannot spend the budget the remaining endpoints need. The share is computed per attempt rather
// than once up front, so an endpoint that fails fast leaves the rest of its share to the next one,
// and the last endpoint gets everything that is left. A ctx with no deadline is passed through.
func attemptContext(ctx context.Context, remaining int) (context.Context, context.CancelFunc) {
	deadline, ok := ctx.Deadline()
	if !ok {
		// Nothing to divide. Cap the attempt anyway so an endpoint that accepts the connection and
		// never answers cannot hold the send open for good.
		return context.WithTimeout(ctx, DefaultPrivateRPCAttemptTimeout)
	}

	if remaining <= 1 {
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

// redactedError carries a send failure with the endpoint URLs taken out of its text.
//
// Redacting only our own log line is not enough: the error is returned to the transaction manager,
// which logs it, and on to the processor, which logs it again. Either would put an API key in the
// logs, so the redaction has to travel with the error rather than be applied at one call site.
//
// Unwrap keeps errors.Is and errors.As working on the original, and only URLs are removed, so the
// substrings the transaction manager classifies on — "nonce too low", "already known",
// "replacement transaction underpriced" — survive intact.
type redactedError struct{ err error }

func (e redactedError) Error() string { return redactURLs(e.err) }
func (e redactedError) Unwrap() error { return e.err }

// redacted wraps err so its text carries no endpoint URL, passing nil through unchanged.
func redacted(err error) error {
	if err == nil {
		return nil
	}

	return redactedError{err}
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
// A rejection of the same transaction as the previous charge is not counted again. A relay that
// will not take one particular claim — one that would revert because a competitor already processed
// the message — is healthy for everything else, and the transaction manager resubmits that claim
// repeatedly, so without this one bad claim could spend the endpoint's whole budget.
//
// Only an answered rejection is deduplicated. A timeout or a transport failure always counts, even
// for the same transaction: the transaction manager republishes an unchanged transaction after a
// generic send error, so a down or hanging endpoint would otherwise be charged exactly once for a
// claim and never reach the threshold — the endpoint would never leave rotation and the fallback
// to the public endpoint would never happen. That is the outage this failover exists for, so the
// two cases have to be told apart; see answeredWithRejection.
//
// Only the immediately preceding charge is compared, not every transaction seen, so two bad claims
// arriving alternately can still trip an endpoint. That is the intended trade: remembering every
// transaction would grow without bound, and repeated refusals of more than one claim are weaker
// evidence of health than of trouble.
func (b *SendingBackend) recordFailure(index int, txHash common.Hash, rejection bool) {
	b.mu.Lock()
	defer b.mu.Unlock()

	if rejection && b.failures[index] > 0 && b.lastCharged[index] == txHash {
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
func (b *SendingBackend) recordSuccess(index int, nonce uint64) {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.failures[index] = 0
	b.failedAt[index] = time.Time{}
	b.lastCharged[index] = common.Hash{}
	b.acceptedNonce[index] = nonce
	b.hasAccepted[index] = true
}

// deprioritiseAlreadyAccepted moves endpoints that already accepted this nonce to the back of the
// order, preserving the configured order within each group.
//
// The transaction manager only re-sends a nonce it has not seen confirmed, so an endpoint that took
// this one and did not get it included has had its turn; offering the replacement to a different
// builder first is a better use of the retry than asking the same one again. Accepting a
// transaction only means the relay received it, never that a builder included it, and that is the
// only signal available here — receipts are polled through the public endpoint, which the backend
// does not see.
//
// Nothing is charged for this. Non-inclusion is usually a fee that was too low or a race already
// lost, not an unhealthy relay, and tripping an endpoint for it would push claims into the public
// mempool for reasons that have nothing to do with the endpoint — the exposure this exists to
// remove. Bounding how long a send waits for inclusion is TX_SEND_TIMEOUT's job.
func (b *SendingBackend) deprioritiseAlreadyAccepted(indices []int, nonce uint64) []int {
	b.mu.Lock()
	defer b.mu.Unlock()

	fresh := make([]int, 0, len(indices))
	alreadyTried := make([]int, 0, len(indices))

	for _, i := range indices {
		if b.hasAccepted[i] && b.acceptedNonce[i] == nonce {
			alreadyTried = append(alreadyTried, i)

			continue
		}

		fresh = append(fresh, i)
	}

	return append(fresh, alreadyTried...)
}

// answeredWithRejection reports whether err is the endpoint saying it will not take this particular
// transaction, as opposed to us never hearing back from it at all.
//
// A JSON-RPC error response means the relay was reachable and formed an opinion about this one
// transaction. A deadline, a cancellation or a transport error means there was no answer, which
// says nothing about the transaction and everything about the endpoint. Classifying on the shape of
// the error rather than on its text keeps this from depending on relay-specific wording.
func answeredWithRejection(err error) bool {
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
		return false
	}

	var netErr net.Error
	if errors.As(err, &netErr) {
		return false
	}

	var rpcErr rpc.Error

	return errors.As(err, &rpcErr)
}
