package utils

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"regexp"
	"slices"
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

// DefaultPrivateRPCConsecutiveFailureCeiling is how many sends an endpoint may refuse in a row
// before it leaves rotation regardless of what its errors say.
//
// This bounds the per-transaction deduplication below. An endpoint that answers every attempt with
// a JSON-RPC error — an internal error, a missing method — looks like a per-claim refusal to that
// deduplication, and the transaction manager resends the same hash every RESUBMISSION_TIMEOUT (48s
// by default), so without a ceiling such an endpoint would hold its place for as long as one claim
// lives. At this ceiling it steps aside after roughly eight minutes of refusing everything.
const DefaultPrivateRPCConsecutiveFailureCeiling = 10

// DefaultPrivateRPCAttemptTimeout caps a single attempt when the caller supplied no deadline.
//
// The transaction manager always calls SendTransaction under its NetworkTimeout, so this does not
// apply in the processor. It keeps the guarantee that one hanging endpoint cannot starve the ones
// behind it from depending on the caller.
const DefaultPrivateRPCAttemptTimeout = 30 * time.Second

// urlInErrorText matches a URL inside an error message, so it can be kept out of the logs.
var urlInErrorText = regexp.MustCompile(`[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s"]*`)

// admission is one endpoint's place in a send's rotation snapshot: which endpoint, and which of
// that endpoint's admissions the send was let in under.
//
// The snapshot is taken once, under the lock, and the sends that follow it run without holding the
// lock, so an endpoint admitted here can leave the rotation before its result comes back — a
// concurrent send can trip it — and can even be re-admitted after that. The generation is what
// tells those apart: it changes every time the endpoint leaves the rotation, so a result that
// outlived the admission it belongs to can be recognised and dropped rather than charged to the
// admission that replaced it. See recordFailure.
type admission struct {
	index      int
	generation uint64
}

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
	consecutive      []int
	generation       []uint64
	highestAccepted  []uint64
	hasAccepted      []bool
	failureThreshold int
	failureCeiling   int
	retryInterval    time.Duration
	now              func() time.Time
	mu               sync.Mutex
	closeOnce        sync.Once
}

// NewSendingBackend wraps public so that sends are routed through private, in priority order.
// private may be empty, in which case every send goes through public unchanged. A nil or
// non-positive retryInterval means DefaultPrivateRPCRetryInterval.
//
// The slice is copied. Everything below is indexed by position in it and read without the caller's
// knowledge from several goroutines, so the backend owns its own order rather than sharing one a
// caller could still be holding.
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
		private:          slices.Clone(private),
		failures:         make([]int, len(private)),
		failedAt:         make([]time.Time, len(private)),
		lastCharged:      make([]common.Hash, len(private)),
		consecutive:      make([]int, len(private)),
		generation:       make([]uint64, len(private)),
		highestAccepted:  make([]uint64, len(private)),
		hasAccepted:      make([]bool, len(private)),
		failureThreshold: DefaultPrivateRPCFailureThreshold,
		failureCeiling:   DefaultPrivateRPCConsecutiveFailureCeiling,
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
		exposed := len(b.private) != 0
		if exposed {
			slog.Warn("No private endpoint in rotation, broadcasting publicly",
				"txHash", tx.Hash().Hex(),
			)
		}

		// DEST_RPC_URL can carry an API key too, so the public path is redacted the same way.
		err := b.ETHBackend.SendTransaction(ctx, tx)

		// Counted only once the broadcast actually went out. A send that failed against our own
		// node never reached the mempool, so counting it would overstate the exposure this metric
		// exists to alert on.
		if err == nil && exposed {
			relayer.PrivateRPCUnavailable.Inc()
		}

		return redacted(err)
	}

	inRotation = b.deprioritiseAlreadyAccepted(inRotation, tx.Nonce())

	var err error

	for attempt, endpoint := range inRotation {
		attemptCtx, cancel := attemptContext(ctx, len(inRotation)-attempt)

		// Checking the attempt's own context rather than the parent's covers both a budget that
		// was already gone and one that ran out between the two, which a check before creating the
		// child would miss. Either way this endpoint never got a usable context, so it never got a
		// send: charging it would trip relays that were never tried. The endpoints already tried
		// keep the failures they earned. This is deliberately read before the send, so an endpoint
		// that spends its whole share in silence still counts.
		//
		// What comes back is the context's error, never the last endpoint's. The two say different
		// things: a rejection describes a send that concluded, and the caller classifies on it —
		// the processor drops a claim whose error is not transient, so an "execution reverted"
		// carried out of here would discard a message whose remaining endpoints were never asked.
		// Running out of budget is transient by definition. Nothing is lost by dropping the
		// rejection, since each one is logged below against the endpoint that produced it.
		if attemptErr := attemptCtx.Err(); attemptErr != nil {
			cancel()

			return redacted(attemptErr)
		}

		err = b.private[endpoint.index].SendTransaction(attemptCtx, tx)

		cancel()

		if err == nil {
			b.recordSuccess(endpoint.index, tx.Nonce())

			return nil
		}

		// A cancellation from our side is not the endpoint's doing. Unlike a deadline — which an
		// endpoint can exhaust by going quiet, and must therefore still count — a cancel only ever
		// comes from the caller, so charging for it could trip healthy relays during shutdown or
		// whenever the transaction manager abandons a send.
		if errors.Is(err, context.Canceled) && ctx.Err() != nil {
			return redacted(err)
		}

		// The endpoint had a usable context and still did not take the transaction. That counts
		// against it whether it refused outright or spent its whole share without answering:
		// hanging is the outage mode this is most meant to survive, so an endpoint that hangs has
		// to be able to trip. Checking the deadline before the send rather than after is what
		// keeps that true for the last endpoint in rotation, whose share is the rest of the
		// budget and which therefore always finds ctx expired once it has hung.
		tripped := b.recordFailure(endpoint, tx.Hash(), answeredWithRejection(err))
		relayer.PrivateRPCFailures.WithLabelValues(strconv.Itoa(endpoint.index)).Inc()

		slog.Warn("Private endpoint refused a transaction",
			"endpoint", endpoint.index,
			"txHash", tx.Hash().Hex(),
			"error", redactURLs(err),
		)

		// Leaving the rotation is the transition an operator cares about — one fewer place to send
		// privately, and the last one leaving means claims reach the public mempool — so it is
		// logged and counted separately from the refusals that led to it.
		if tripped {
			relayer.PrivateRPCTrips.WithLabelValues(strconv.Itoa(endpoint.index)).Inc()

			slog.Warn("Private endpoint taken out of rotation",
				"endpoint", endpoint.index,
				"retryIn", b.retryInterval,
			)
		}
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
		//
		// The cap is per attempt, so with no deadline to divide a send across N endpoints can take
		// up to N times it. That is the price of having no budget to share out, and it is bounded,
		// which is the property that matters. Callers wanting a bound on the whole send pass a
		// deadline; the transaction manager always does, via NetworkTimeout.
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

// redactedLink is one step of a redacted error chain: its text carries no URL, and unwrapping it
// continues to the error it was built from.
//
// It exists so that redactedError.Unwrap and .Cause can hand out something that still prints
// redacted. Returning the wrapped error directly from either would undo the redaction for any
// caller that logs what it was given, which is what Cause in particular exists to be used for.
type redactedLink struct{ err error }

func (e redactedLink) Error() string { return redactURLs(e.err) }
func (e redactedLink) Unwrap() error { return e.err }

// Format keeps the redaction in place whichever verb prints the error.
//
// Error covers %s, %v and %q, but %#v does not consult it: it prints the struct's fields, and the
// field is the unredacted error. fmt asks a Formatter first, so implementing one is what makes the
// guarantee hold regardless of how a caller logs what it is handed.
func (e redactedLink) Format(f fmt.State, verb rune) {
	switch verb {
	case 'v':
		if f.Flag('#') {
			// Deliberately not Go syntax. A compilable representation would have to name the
			// wrapped error, which is the thing being kept out of the output.
			fmt.Fprintf(f, "utils.redacted(%q)", e.Error())

			return
		}

		fmt.Fprint(f, e.Error())
	case 's':
		fmt.Fprint(f, e.Error())
	case 'q':
		fmt.Fprintf(f, "%q", e.Error())
	default:
		fmt.Fprintf(f, "%%!%c(utils.redacted=%s)", verb, e.Error())
	}
}

// redactedError carries a send failure with the endpoint URLs taken out of its text.
//
// Redacting only our own log line is not enough: the error is returned to the transaction manager,
// which logs it, and on to the processor, which logs it again. Either would put an API key in the
// logs, so the redaction has to travel with the error rather than be applied at one call site.
//
// The chain is redactedError -> redactedLink -> the original. errors.Is and errors.As walk it to
// the end, so identity is preserved, and only URLs are removed from the text, so the substrings
// the transaction manager classifies on — "nonce too low", "already known", "replacement
// transaction underpriced" — survive intact. What the extra link buys is that the first step out
// of the wrapper, by either Unwrap or Cause, still prints redacted.
//
// The guarantee is about printing, not reachability: errors.As into the concrete type hands over
// the original, as it must, and so does unwrapping twice. Both are deliberate acts by a caller
// that wants the underlying error, rather than the incidental logging this protects against.
type redactedError struct{ redactedLink }

// Unwrap returns the next link rather than the original, so a caller that logs what it unwraps
// still gets redacted text. errors.Is and errors.As traverse transitively, so they are unaffected.
func (e redactedError) Unwrap() error { return e.redactedLink }

// Cause satisfies github.com/pkg/errors, which this repository also uses and which does not follow
// Unwrap. Without it, code reaching for the cause would stop at the wrapper. It returns the
// redacted link rather than the original: Cause exists to be inspected and logged, and it walks
// the whole chain in one call, which makes it the likeliest way for an endpoint URL to reach a log
// by accident. The link implements no Cause of its own, so the walk stops there.
func (e redactedError) Cause() error { return e.redactedLink }

// redacted wraps err so its text carries no endpoint URL, passing nil through unchanged.
func redacted(err error) error {
	if err == nil {
		return nil
	}

	return redactedError{redactedLink{err}}
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

// inRotation returns the private endpoints currently usable, in priority order and each carrying
// the generation it is admitted under, re-admitting any whose retry interval has elapsed.
func (b *SendingBackend) inRotation() []admission {
	b.mu.Lock()

	now := b.now()
	admitted := make([]admission, 0, len(b.private))

	var readmitted []int

	for i := range b.private {
		if !b.failedAt[i].IsZero() {
			if now.Sub(b.failedAt[i]) < b.retryInterval {
				continue
			}

			// Back from a trip with a fresh budget, rather than the spent one that would trip it
			// again on its first failure.
			//
			// The generation is deliberately not touched here. It was already moved on when the
			// endpoint left the rotation, which is what makes a send still in flight from before
			// that trip recognisable — and a fresh budget is exactly what such a send must not be
			// allowed to spend.
			b.failedAt[i] = time.Time{}
			b.failures[i] = 0
			b.lastCharged[i] = common.Hash{}
			b.consecutive[i] = 0

			// highestAccepted and hasAccepted are deliberately kept. They record which nonces this
			// endpoint has already taken, which does not stop being true because it went quiet for
			// a while: a resend of one of them is still better offered elsewhere first. Clearing
			// them would re-offer a nonce the endpoint already holds, which is the duplicate the
			// mark exists to avoid. The cost is that the mark never shrinks, which is fine — it
			// only ever moves a resend later in the order, never out of it.
			readmitted = append(readmitted, i)
		}

		admitted = append(admitted, admission{index: i, generation: b.generation[i]})
	}

	b.mu.Unlock()

	// Logged outside the lock, and after it rather than under a defer, so a rare transition does
	// not put a write to the log inside the path every send takes.
	for _, i := range readmitted {
		slog.Info("Private endpoint back in rotation",
			"endpoint", i,
			"after", b.retryInterval,
		)
	}

	return admitted
}

// recordFailure counts a refused transaction against the endpoint the send was admitted to, taking
// it out of rotation once it has refused failureThreshold distinct transactions in a row.
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
//
// A failure belonging to an admission the endpoint has already left is dropped entirely. Sends run
// concurrently and each takes its own rotation snapshot, so when an endpoint goes down several
// sends are typically in flight against it and only the first of them to come back trips it; the
// rest were admitted under the same generation and would otherwise each re-run the whole tally.
// That would push a later timestamp into failedAt every time — restarting the retry interval from
// the last straggler instead of from the moment the endpoint left the rotation, which under
// sustained load can hold a recovered endpoint out for far longer than the configured interval —
// and would report the one departure as a trip once per straggler, inflating a metric that exists
// to count exactly that transition. Comparing generations also covers the longer-lived case the
// zero check on failedAt does not: a send that outlives the whole trip and lands after the endpoint
// has been re-admitted, whose failure belongs to the outage that is over rather than to the fresh
// budget it would otherwise spend.
//
// A success is not screened this way. It is proof the endpoint is taking transactions right now,
// whichever admission asked, and that is worth acting on immediately; see recordSuccess.
//
// It reports whether this failure is what took the endpoint out of rotation, so the caller can log
// and count that transition without holding the lock.
func (b *SendingBackend) recordFailure(endpoint admission, txHash common.Hash, rejection bool) (tripped bool) {
	b.mu.Lock()
	defer b.mu.Unlock()

	index := endpoint.index

	if b.generation[index] != endpoint.generation {
		return false
	}

	b.consecutive[index]++

	// An endpoint refusing this many sends in a row is not being fussy about one claim, whatever
	// its errors say, so it steps aside without consulting the deduplication below.
	if b.consecutive[index] >= b.failureCeiling {
		b.leaveRotation(index)

		return true
	}

	if rejection && b.failures[index] > 0 && b.lastCharged[index] == txHash {
		return false
	}

	b.lastCharged[index] = txHash
	b.failures[index]++

	if b.failures[index] >= b.failureThreshold {
		b.leaveRotation(index)

		return true
	}

	return false
}

// leaveRotation takes the endpoint at index out of rotation for the retry interval, ending the
// admission its in-flight sends were let in under so their results cannot be charged to the next
// one. The caller holds the lock.
func (b *SendingBackend) leaveRotation(index int) {
	b.failedAt[index] = b.now()
	b.generation[index]++
}

// recordSuccess returns the endpoint at index to full health. Only consecutive failures trip an
// endpoint, so one transaction it would not take does not cost it its turn, and an endpoint that
// just took one is not down whatever its recent record.
//
// This holds even for a send admitted before a trip that only now came back: the endpoint has
// demonstrably just accepted a transaction, so it belongs back in rotation whatever the tally from
// the outage says. The generation is left alone, which keeps the failures still in flight from that
// outage from being charged against the budget this clears.
func (b *SendingBackend) recordSuccess(index int, nonce uint64) {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.failures[index] = 0
	b.failedAt[index] = time.Time{}
	b.lastCharged[index] = common.Hash{}
	b.consecutive[index] = 0

	if !b.hasAccepted[index] || nonce > b.highestAccepted[index] {
		b.highestAccepted[index] = nonce
	}

	b.hasAccepted[index] = true
}

// deprioritiseAlreadyAccepted moves endpoints that already accepted this nonce to the back of the
// order, preserving the configured order within each group. "Already accepted" means at or below
// the highest nonce the endpoint has taken, not that exact nonce; see below.
//
// The transaction manager only re-sends a nonce it has not seen confirmed, so an endpoint that took
// this one and did not get it included has had its turn; offering the replacement to a different
// builder first is a better use of the retry than asking the same one again. Accepting a
// transaction only means the relay received it, never that a builder included it, and that is the
// only signal available here — receipts are polled through the public endpoint, which the backend
// does not see.
//
// The comparison is against the highest nonce the endpoint has accepted, not the last one, because
// the processor handles claims concurrently: several nonces are in flight at once, and a single
// slot per endpoint would be overwritten by whichever landed most recently, losing the record for
// every other pending claim. A resend carries a nonce the manager has not seen confirmed, so
// "at or below the highest this endpoint took" is the durable form of "it has already had this
// one". A first send that arrives out of order behind a higher nonce is deprioritised too; that
// only reorders private endpoints against each other and costs nothing.
//
// Nothing is charged for this. Non-inclusion is usually a fee that was too low or a race already
// lost, not an unhealthy relay, and tripping an endpoint for it would push claims into the public
// mempool for reasons that have nothing to do with the endpoint — the exposure this exists to
// remove. Bounding how long a send waits for inclusion is TX_SEND_TIMEOUT's job.
func (b *SendingBackend) deprioritiseAlreadyAccepted(admitted []admission, nonce uint64) []admission {
	b.mu.Lock()
	defer b.mu.Unlock()

	fresh := make([]admission, 0, len(admitted))
	alreadyTried := make([]admission, 0, len(admitted))

	for _, endpoint := range admitted {
		if b.hasAccepted[endpoint.index] && nonce <= b.highestAccepted[endpoint.index] {
			alreadyTried = append(alreadyTried, endpoint)

			continue
		}

		fresh = append(fresh, endpoint)
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
