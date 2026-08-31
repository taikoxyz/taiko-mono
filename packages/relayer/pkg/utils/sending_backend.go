package utils

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/txpool"
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
// The claims also have to be distinct, which is judged by nonce; see recordFailure.
const DefaultPrivateRPCFailureThreshold = 3

// DefaultPrivateRPCConsecutiveFailureCeiling is how many sends an endpoint may refuse in a row
// before it leaves rotation regardless of what its errors say.
//
// This bounds the per-nonce deduplication below. An endpoint that answers every attempt with
// a JSON-RPC error — an internal error, a missing method — looks like a per-claim refusal to that
// deduplication, and the transaction manager resends the same nonce every RESUBMISSION_TIMEOUT (48s
// by default), so without a ceiling such an endpoint would hold its place for as long as one claim
// lives. At this ceiling it steps aside after roughly eight minutes of refusing everything.
const DefaultPrivateRPCConsecutiveFailureCeiling = 10

// MinPrivateRPCAttemptShare is the smallest share worth handing one endpoint.
//
// The budget being divided is the caller's, which for the processor is the transaction manager's
// RPC_TIMEOUT — 12 seconds by default, not TX_SEND_TIMEOUT. Divided among several endpoints that
// leaves a few seconds each, and dividing further produces slices too short for a relay to answer
// in: the endpoint fails on time rather than on health, and a timeout is charged with no
// deduplication, so endpoints flap in and out of rotation on a budget rather than on an outage.
//
// Below this, the attempt is given the whole remaining budget instead. The endpoints behind it then
// find the deadline gone and are skipped without being charged, which is the right answer: better
// to ask one endpoint properly than several too briefly to hear back from any.
//
// Deliberately low. Both default relays answer a send in well under a second — they acknowledge
// receipt, they do not wait for inclusion — so at the 12 second default this only bites past a
// dozen endpoints, or when an operator has lowered RPC_TIMEOUT. Set higher it would stop dividing
// the budget in ordinary configurations, and the first endpoint would take all of it while the
// rest were never asked.
const MinPrivateRPCAttemptShare = time.Second

// DefaultPrivateRPCAllRefusedLimit is how many sends of one nonce may be refused by every endpoint
// in rotation before that claim is offered publicly.
//
// Tripping is per endpoint, so a claim that every relay declines individually trips nobody: each is
// charged once for it, other claims keep clearing their tallies, and the rotation never empties. The
// claim then loops until TX_SEND_TIMEOUT with nothing to show for it and no metric moving, because
// the relays are healthy and only this claim is unwanted.
//
// Going public gives a competitor the message and proof, which is what this package exists to
// prevent, so it is the last resort rather than the first — but a claim that never lands is worth
// less than one landed in the open. At the 48s resubmission default this is a couple of minutes of
// trying privately first.
const DefaultPrivateRPCAllRefusedLimit = 3

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

// blobBaseFeeBackend and rpcBackend mirror the two optional interfaces the transaction manager's
// gas price estimator looks for on its backend. They are unexported there, so they have to be
// restated here to be answered; see BlobBaseFee.
type blobBaseFeeBackend interface {
	BlobBaseFee(ctx context.Context) (*big.Int, error)
}

type rpcBackend interface {
	Client() *rpc.Client
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
	hosts            []string
	allRefusedNonce  uint64
	allRefusedCount  int
	hasAllRefused    bool
	allRefusedLimit  int
	failures         []int
	failedAt         []time.Time
	lastCharged      []uint64
	hasCharged       []bool
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
// hosts are the endpoints' host names, positionally or otherwise; they are removed from the text of
// any error this backend returns, since a name that fails to resolve appears outside any URL. They
// are only used for redaction, so a caller with none can pass nil.
//
// The slices are copied. Everything below is indexed by position in private and read without the
// caller's knowledge from several goroutines, so the backend owns its own order rather than sharing
// one a caller could still be holding.
func NewSendingBackend(
	public txmgr.ETHBackend,
	private []TxSender,
	hosts []string,
	retryInterval *time.Duration,
) *SendingBackend {
	interval := DefaultPrivateRPCRetryInterval
	if retryInterval != nil && *retryInterval > 0 {
		interval = *retryInterval
	}

	backend := &SendingBackend{
		ETHBackend:       public,
		private:          slices.Clone(private),
		hosts:            slices.Clone(hosts),
		failures:         make([]int, len(private)),
		failedAt:         make([]time.Time, len(private)),
		lastCharged:      make([]uint64, len(private)),
		hasCharged:       make([]bool, len(private)),
		consecutive:      make([]int, len(private)),
		generation:       make([]uint64, len(private)),
		highestAccepted:  make([]uint64, len(private)),
		hasAccepted:      make([]bool, len(private)),
		failureThreshold: DefaultPrivateRPCFailureThreshold,
		failureCeiling:   DefaultPrivateRPCConsecutiveFailureCeiling,
		allRefusedLimit:  DefaultPrivateRPCAllRefusedLimit,
		retryInterval:    interval,
		now:              time.Now,
	}

	// Prometheus creates a labelled child on first use, so a counter that has never been touched
	// is absent rather than zero — and increase() over an absent-then-1 series evaluates to 0.
	// The first trip, the transition most worth alerting on, would be the one that never fired.
	// Touching every label value here gives each series a zero to rise from.
	for i := range backend.private {
		endpoint := strconv.Itoa(i)

		relayer.PrivateRPCFailures.WithLabelValues(endpoint).Add(0)
		relayer.PrivateRPCSends.WithLabelValues(endpoint).Add(0)
		relayer.PrivateRPCTrips.WithLabelValues(endpoint).Add(0)
		relayer.PrivateRPCHeldNonce.WithLabelValues(endpoint).Add(0)
		relayer.PrivateRPCInRotation.WithLabelValues(endpoint).Set(1)
	}

	return backend
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

		return b.redacted(err)
	}

	inRotation = b.prioritiseNonceHolder(inRotation, tx.Nonce())

	var err error

	// Only a send every endpoint answered counts toward the public fallback below. A timeout or a
	// transport failure is an outage, which tripping already handles by emptying the rotation; the
	// fallback exists for the opposite case, healthy relays that all decline one claim.
	allAnsweredRejection := true

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

			return b.redacted(attemptErr)
		}

		err = b.private[endpoint.index].SendTransaction(attemptCtx, tx)

		cancel()

		if err == nil {
			b.clearAllRefused(tx.Nonce())
			b.recordSuccess(endpoint.index, tx.Nonce())
			relayer.PrivateRPCSends.WithLabelValues(strconv.Itoa(endpoint.index)).Inc()

			return nil
		}

		// A cancellation from our side is not the endpoint's doing. Unlike a deadline — which an
		// endpoint can exhaust by going quiet, and must therefore still count — a cancel only ever
		// comes from the caller, so charging for it could trip healthy relays during shutdown or
		// whenever the transaction manager abandons a send.
		if errors.Is(err, context.Canceled) && ctx.Err() != nil {
			return b.redacted(err)
		}

		// An endpoint that answers because it is already holding this nonce is not refusing the
		// claim, and steering the resend to it is the whole point of doing so. Nothing is charged.
		if holdsTheNonce(err) {
			// Not a refusal, so it cannot count towards the public fallback either. Every endpoint
			// answering that it holds this nonce means the claim is already everywhere it needs to
			// be — broadcasting it publicly then would leak a claim the relays are all carrying.
			allAnsweredRejection = false

			relayer.PrivateRPCHeldNonce.WithLabelValues(strconv.Itoa(endpoint.index)).Inc()

			// Charged against the consecutive count but not the failure tally. An endpoint that
			// answers this way for every send is not healthy however good its reason, and skipping
			// recordFailure entirely meant it could never reach the ceiling that exists to end
			// exactly that: it would hold its place indefinitely while nothing was ever sent
			// through it.
			if tripped := b.recordHeldNonce(endpoint); tripped {
				relayer.PrivateRPCTrips.WithLabelValues(strconv.Itoa(endpoint.index)).Inc()

				slog.Warn("Private endpoint taken out of rotation",
					"endpoint", endpoint.index,
					"reason", "answered that it holds every nonce offered",
					"retryIn", b.retryInterval,
				)
			}

			slog.Info("Private endpoint already holds this nonce",
				"endpoint", endpoint.index,
				"nonce", tx.Nonce(),
			)

			continue
		}

		// The endpoint had a usable context and still did not take the transaction. That counts
		// against it whether it refused outright or spent its whole share without answering:
		// hanging is the outage mode this is most meant to survive, so an endpoint that hangs has
		// to be able to trip. Checking the deadline before the send rather than after is what
		// keeps that true for the last endpoint in rotation, whose share is the rest of the
		// budget and which therefore always finds ctx expired once it has hung.
		rejection := answeredWithRejection(err)
		if !rejection {
			allAnsweredRejection = false
		}

		tripped := b.recordFailure(endpoint, tx.Nonce(), rejection)
		relayer.PrivateRPCFailures.WithLabelValues(strconv.Itoa(endpoint.index)).Inc()

		slog.Warn("Private endpoint refused a transaction",
			"endpoint", endpoint.index,
			"txHash", tx.Hash().Hex(),
			"error", redactEndpoints(err, b.hosts),
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

	// Every endpoint in rotation refused this claim. Tripping is per endpoint and each was charged
	// only once for it, so nobody leaves the rotation over one unwanted claim and the fallback
	// below would never be reached — the claim would simply loop until TX_SEND_TIMEOUT.
	if allAnsweredRejection && b.countAllRefused(tx.Nonce()) {
		slog.Warn("Every private endpoint refused this claim, broadcasting publicly",
			"txHash", tx.Hash().Hex(),
			"afterSends", b.allRefusedLimit,
		)

		publicErr := b.ETHBackend.SendTransaction(ctx, tx)
		if publicErr == nil {
			b.clearAllRefused(tx.Nonce())
			relayer.PrivateRPCAllRefused.Inc()

			return nil
		}

		// The public attempt is the last and most complete thing tried, so it is what the caller
		// should classify on: a refusal from a relay may not be transient, but a public endpoint
		// that could not be reached is.
		return b.redacted(publicErr)
	}

	return b.redacted(err)
}

// clearAllRefused forgets the refusal run for this nonce, because an endpoint has just taken it.
func (b *SendingBackend) clearAllRefused(nonce uint64) {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.hasAllRefused && b.allRefusedNonce == nonce {
		b.allRefusedCount = 0
	}
}

// countAllRefused records that every endpoint in rotation refused this nonce, and reports whether
// that has now happened often enough in a row to justify broadcasting it publicly.
//
// One slot rather than a map: the transaction manager resends an unconfirmed nonce every
// RESUBMISSION_TIMEOUT, so consecutive refusals of one claim land here in a row, and a different
// nonce means a different claim and starts the count again. Claims are handled concurrently, so
// two claims both being refused can reset each other's count — the same trade the failure
// deduplication makes, and with the same consequence: the fallback is delayed, never skipped, and
// only for as long as both claims keep failing.
//
// The count is cleared by a send some endpoint accepted, and by nothing else — in particular not by
// firing. Clearing it there cost the claim the threshold it had just earned: if the public send then
// failed, three more all-refused sends were needed before the fallback could be tried again, which
// at the 48s resubmission default is past the two-minute TxNotInMempoolTimeout. The claim would end
// that send never having reached the mempool at all, which is the one thing this exists to prevent.
// Once the limit is reached the fallback is therefore offered on every subsequent send of that
// nonce, until one of them lands.
func (b *SendingBackend) countAllRefused(nonce uint64) bool {
	b.mu.Lock()
	defer b.mu.Unlock()

	if !b.hasAllRefused || b.allRefusedNonce != nonce {
		b.allRefusedNonce = nonce
		b.allRefusedCount = 0
		b.hasAllRefused = true
	}

	b.allRefusedCount++

	return b.allRefusedCount >= b.allRefusedLimit
}

// attemptContext gives one endpoint its share of the time left on ctx, so an endpoint that hangs
// cannot spend the budget the remaining endpoints need. The share is floored at
// MinPrivateRPCAttemptShare; below that the attempt takes the whole remaining budget. The share is
// computed per attempt rather than once up front, so a fast failure leaves the rest to the next one,
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

	// A share too short to hear an answer in is worse than no division: it charges the endpoint
	// for the budget rather than for its health. Hand the attempt everything left instead.
	share := time.Until(deadline) / time.Duration(remaining)
	if share < MinPrivateRPCAttemptShare {
		return context.WithCancel(ctx)
	}

	return context.WithTimeout(ctx, share)
}

// redactEndpoints removes endpoints from an error's text. Transport errors quote the URL they were
// dialling, which can carry an API key in its path or query; the endpoint's position is logged
// alongside, and that is what identifies the relay without publishing a credential.
//
// The URL pattern alone is not enough. A name that fails to resolve, or a certificate that does not
// match, puts the host in the error outside any URL — `lookup relay.example.com on 10.0.0.1:53: no
// such host` — so the configured hosts are replaced by name as well.
//
// What survives, in that same example, is `10.0.0.1:53`: addresses the resolver produced rather than
// names we were configured with. The IP a dial reports goes the same way. Matching bare `ip:port`
// shapes in error text is the kind of pattern that quietly stops matching, so this does not try —
// a relay's provider can still be inferred from a failing deployment's logs.
func redactEndpoints(err error, hosts []string) string {
	text := urlInErrorText.ReplaceAllString(err.Error(), "[redacted]")

	for _, host := range hosts {
		if host == "" {
			continue
		}

		text = strings.ReplaceAll(text, host, "[redacted]")
	}

	return text
}

// redactedLink is one step of a redacted error chain: its text carries no URL, and unwrapping it
// continues to the error it was built from.
//
// It exists so that redactedError.Unwrap and .Cause can hand out something that still prints
// redacted. Returning the wrapped error directly from either would undo the redaction for any
// caller that logs what it was given, which is what Cause in particular exists to be used for.
type redactedLink struct {
	err   error
	hosts []string
}

func (e redactedLink) Error() string { return redactEndpoints(e.err, e.hosts) }
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

// redacted wraps err with this backend's configured hosts.
func (b *SendingBackend) redacted(err error) error {
	return Redact(err, b.hosts)
}

// Redact wraps err so its text carries neither an endpoint URL nor any of the given hosts, passing
// nil through unchanged. Exported so that the code which dials the endpoints — where a failure
// quotes the URL it was given, API key and all — can use the same redaction as the send path.
func Redact(err error, hosts []string) error {
	if err == nil {
		return nil
	}

	return redactedError{redactedLink{err: err, hosts: hosts}}
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

// BlobBaseFee answers the blob base fee out of the wrapped backend.
//
// txmgr.ETHBackend does not carry this method, but the transaction manager's gas price estimator
// reaches past that interface for it: whenever the head block has an ExcessBlobGas — every
// post-Dencun Ethereum block — it type-asserts its backend for a BlobBaseFee or a Client method and
// fails the whole send when it finds neither. Embedding an interface promotes only that interface's
// methods, so a wrapper answers neither assertion however capable the endpoint underneath is, and
// craftTx would reject every claim before it was ever signed. That failure carries no transient
// substring, so the processor would dead-letter each one.
//
// Only this method is defined, never Client: the estimator checks this one first, and a Client that
// returned nil for a backend that has none would hand the caller a nil dereference in place of the
// error it expects.
func (b *SendingBackend) BlobBaseFee(ctx context.Context) (*big.Int, error) {
	if backend, ok := b.ETHBackend.(blobBaseFeeBackend); ok {
		return backend.BlobBaseFee(ctx)
	}

	// The same fallback the estimator would have run itself, for a backend that exposes the raw
	// client rather than the typed call.
	if backend, ok := b.ETHBackend.(rpcBackend); ok {
		var fee hexutil.Big
		if err := backend.Client().CallContext(ctx, &fee, "eth_blobBaseFee"); err != nil {
			return nil, err
		}

		return (*big.Int)(&fee), nil
	}

	return nil, errors.New("backend does not support blob base fee rpc")
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
			b.lastCharged[i] = 0
			b.hasCharged[i] = false
			b.consecutive[i] = 0

			// highestAccepted and hasAccepted are deliberately kept. They record which nonces this
			// endpoint has already taken, which does not stop being true because it went quiet for
			// a while: a resend of one of them still belongs with the relay holding it, so that the
			// replacement retires the stale variant instead of racing it. The cost is that the mark
			// never shrinks, which is fine — it only ever moves a resend earlier in the order,
			// never out of it.
			readmitted = append(readmitted, i)
		}

		admitted = append(admitted, admission{index: i, generation: b.generation[i]})
	}

	// Set under the lock, like the trip that clears it. Outside, a re-admission racing a fresh trip
	// could land after that trip's Set(0) and leave the gauge claiming the endpoint is in rotation
	// for the whole retry interval — the one thing this gauge exists to report accurately.
	for _, i := range readmitted {
		relayer.PrivateRPCInRotation.WithLabelValues(strconv.Itoa(i)).Set(1)
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
// A rejection carrying the same nonce as the previous charge is not counted again. A relay that
// will not take one particular claim — one that would revert because a competitor already processed
// the message — is healthy for everything else, and the transaction manager resubmits that claim
// repeatedly, so without this one bad claim could spend the endpoint's whole budget.
//
// The nonce identifies the claim; the transaction hash does not. publishTx sets bumpFees after any
// successful publish, and with several endpoints configured a send succeeds as soon as one of them
// accepts — so the next resubmission of a claim another endpoint refused arrives re-signed at a
// higher fee, under a new hash. Keyed on the hash, every retry of one bad claim looked like a fresh
// refusal and walked a healthy endpoint to the threshold in three rounds. The nonce is what survives
// a fee bump, and signWithNextNonce gives distinct claims distinct nonces, so two bad claims
// arriving alternately still trip an endpoint as intended.
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
func (b *SendingBackend) recordFailure(endpoint admission, nonce uint64, rejection bool) (tripped bool) {
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

	if rejection && b.hasCharged[index] && b.lastCharged[index] == nonce {
		return false
	}

	b.lastCharged[index] = nonce
	b.hasCharged[index] = true
	b.failures[index]++

	if b.failures[index] >= b.failureThreshold {
		b.leaveRotation(index)

		return true
	}

	return false
}

// recordHeldNonce counts an endpoint answering that it already holds the nonce.
//
// It is not a refusal, so it does not touch the failure tally that the threshold reads and does not
// mark the endpoint unhealthy. But it does count towards the consecutive ceiling: an endpoint that
// answers this way to everything is taking no transactions, whatever its reason, and without this
// it could never reach the bound that exists for precisely that — it skipped the accounting
// altogether and kept its place forever while nothing went through it.
//
// A send it accepts clears the count, as it clears every other.
func (b *SendingBackend) recordHeldNonce(endpoint admission) (tripped bool) {
	b.mu.Lock()
	defer b.mu.Unlock()

	index := endpoint.index

	if b.generation[index] != endpoint.generation {
		return false
	}

	b.consecutive[index]++

	if b.consecutive[index] >= b.failureCeiling {
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

	relayer.PrivateRPCInRotation.WithLabelValues(strconv.Itoa(index)).Set(0)
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
	b.lastCharged[index] = 0
	b.hasCharged[index] = false
	b.consecutive[index] = 0

	relayer.PrivateRPCInRotation.WithLabelValues(strconv.Itoa(index)).Set(1)

	if !b.hasAccepted[index] || nonce > b.highestAccepted[index] {
		b.highestAccepted[index] = nonce
	}

	b.hasAccepted[index] = true
}

// prioritiseNonceHolder moves the endpoints that have already accepted this nonce to the front of
// the order, preserving the configured order within each group. "Already accepted" means at or
// below the highest nonce the endpoint has taken, not that exact nonce; see below.
//
// A relay replaces a transaction the way a mempool does: same nonce, higher fee. So the endpoint
// already holding this nonce is the one place a resend does something useful — it retires the stale
// low-fee variant and leaves one transaction live for that nonce. Offering the resend elsewhere
// leaves the original still being offered by the first relay's builders and the replacement by
// another's, with no single authority to enforce one transaction per nonce, which is how two
// variants of one claim end up racing each other.
//
// Only a resend is steered. A nonce no endpoint has taken is a first send and keeps the configured
// order, so the preferred relay is still tried first for new work.
//
// The comparison is against the highest nonce the endpoint has accepted, not the last one, because
// the processor handles claims concurrently: several nonces are in flight at once, and a single
// slot per endpoint would be overwritten by whichever landed most recently, losing the record for
// every other pending claim. A resend carries a nonce the manager has not seen confirmed, so
// "at or below the highest this endpoint took" is the durable form of "it has already had this
// one". A first send arriving out of order behind a higher nonce is treated as a resend by that
// test; that only reorders private endpoints against each other and costs nothing.
//
// Nothing is charged for the reordering itself, and nothing is charged for what the holder answers
// either: a relay that already has the nonce replies "replacement transaction underpriced" or
// "already known", which reads as a refusal but is evidence it is holding the claim. See
// holdsTheNonce. Non-inclusion is usually a fee that was too low or a race already lost, not an
// unhealthy relay, and tripping an endpoint for it would push claims into the public mempool for
// reasons that have nothing to do with the endpoint — the exposure this exists to remove. Bounding
// how long a send waits for inclusion is TX_SEND_TIMEOUT's job.
func (b *SendingBackend) prioritiseNonceHolder(admitted []admission, nonce uint64) []admission {
	b.mu.Lock()
	defer b.mu.Unlock()

	holders := make([]admission, 0, len(admitted))
	rest := make([]admission, 0, len(admitted))

	for _, endpoint := range admitted {
		if b.hasAccepted[endpoint.index] && nonce <= b.highestAccepted[endpoint.index] {
			holders = append(holders, endpoint)

			continue
		}

		rest = append(rest, endpoint)
	}

	return append(holders, rest...)
}

// holdsTheNonce reports whether the endpoint answered because it already has this nonce, rather
// than because it will not take the claim.
//
// Resends go to the endpoint holding the nonce first, which is the point: a relay replaces a
// transaction the way a mempool does, and the holder is where the replacement retires the stale
// variant. But a relay that already has the nonce answers "replacement transaction underpriced" or
// "already known" — JSON-RPC errors, so they read as refusals to answeredWithRejection, and a run
// of nonce collisions after a resetNonce carries distinct nonces, so the deduplication never
// suppresses them. Three of those took the preferred relay out of rotation for five minutes, for
// doing exactly what steering the resend to it was meant to achieve.
//
// Both answers are evidence the endpoint is holding the claim, so neither is charged.
//
// This matches on geth's wording, which reaches us only from a relay that proxies its node's
// txpool errors verbatim. Neither shipped default does: Flashbots' rpc-endpoint answers a duplicate
// resubmission with success and collapses its own rejections to -32603, and MEV Blocker publishes
// no such wording. So in the recommended configuration this is inert — and so is the over-charging
// it exists to prevent. It is here for relays that do proxy geth, and it is worth knowing that a
// change of wording on either side moves both.
func holdsTheNonce(err error) bool {
	if err == nil {
		return false
	}

	text := err.Error()

	return strings.Contains(text, txpool.ErrReplaceUnderpriced.Error()) ||
		strings.Contains(text, txpool.ErrAlreadyKnown.Error())
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
