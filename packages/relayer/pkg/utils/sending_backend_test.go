package utils

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// fakeBackend stands in for the chain's own endpoint. The embedded interface satisfies the type
// without implementing the methods no test reaches.
type fakeBackend struct {
	txmgr.ETHBackend
	mu                sync.Mutex
	pendingNonce      uint64
	pendingNonceCalls int
	sent              []*types.Transaction
	closed            bool
	closeCalls        int
}

func (f *fakeBackend) PendingNonceAt(_ context.Context, _ common.Address) (uint64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.pendingNonceCalls++

	return f.pendingNonce, nil
}

func (f *fakeBackend) SendTransaction(_ context.Context, tx *types.Transaction) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.sent = append(f.sent, tx)

	return nil
}

func (f *fakeBackend) Close() {
	f.closed = true
	f.closeCalls++
}

// errBackend is a public backend whose sends always fail.
type errBackend struct {
	fakeBackend
	err error
}

func (f *errBackend) SendTransaction(_ context.Context, _ *types.Transaction) error { return f.err }

// fakeSender stands in for a private endpoint.
type fakeSender struct {
	mu     sync.Mutex
	err    error
	sent   []*types.Transaction
	closed bool
}

func (f *fakeSender) SendTransaction(_ context.Context, tx *types.Transaction) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.err != nil {
		return f.err
	}

	f.sent = append(f.sent, tx)

	return nil
}

func (f *fakeSender) Close() { f.closed = true }

// rpcRejection models a JSON-RPC error response: the relay was reachable and answered that it will
// not take this transaction. go-ethereum surfaces these as rpc.Error, which is how the backend
// tells them apart from never hearing back at all.
type rpcRejection struct{ msg string }

func (e rpcRejection) Error() string  { return e.msg }
func (e rpcRejection) ErrorCode() int { return -32000 }

func testTx() *types.Transaction {
	return txWithNonce(7)
}

// txWithNonce builds a transaction distinct from any other nonce, so a test can tell "this relay
// refused three different claims" from "this relay refused the same claim three times".
func txWithNonce(nonce uint64) *types.Transaction {
	return types.NewTx(&types.DynamicFeeTx{Nonce: nonce, Gas: 21_000})
}

// newTestBackend builds a backend over one public endpoint and two private ones, with a clock the
// test controls so retry intervals can be exercised without sleeping.
func newTestBackend(t *testing.T, retryInterval *time.Duration) (
	b *SendingBackend,
	public *fakeBackend,
	first *fakeSender,
	second *fakeSender,
	clock *time.Time,
) {
	t.Helper()

	public = &fakeBackend{}
	first = &fakeSender{}
	second = &fakeSender{}

	now := time.Date(2026, time.August, 29, 0, 0, 0, 0, time.UTC)
	clock = &now

	b = NewSendingBackend(public, []TxSender{first, second}, retryInterval)
	b.now = func() time.Time { return *clock }

	return b, public, first, second, clock
}

// trip refuses enough distinct transactions in a row to take a private endpoint out of rotation.
func trip(b *SendingBackend, index int) {
	for i := 0; i < DefaultPrivateRPCFailureThreshold; i++ {
		b.recordFailure(index, txWithNonce(uint64(i)).Hash(), false)
	}
}

func TestSendingBackend_ReadsGoToThePublicEndpoint(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)
	public.pendingNonce = 42

	// The nonce has to come from our own node. Resolving it against a private endpoint is what
	// would let two concurrent claims be signed with the same nonce.
	nonce, err := b.PendingNonceAt(context.Background(), common.Address{})

	require.NoError(t, err)
	assert.Equal(t, uint64(42), nonce)
	assert.Equal(t, 1, public.pendingNonceCalls)
	assert.Empty(t, first.sent)
	assert.Empty(t, second.sent)
}

func TestSendingBackend_SendsThroughThePublicEndpointWhenNoneIsConfigured(t *testing.T) {
	public := &fakeBackend{}
	b := NewSendingBackend(public, nil, nil)

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	assert.Len(t, public.sent, 1)
	assert.Equal(t, 0, b.NumPrivateEndpoints())
}

func TestSendingBackend_SendsThroughTheFirstPrivateEndpoint(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	assert.Len(t, first.sent, 1, "the claim must not reach the public mempool")
	assert.Empty(t, second.sent)
	assert.Empty(t, public.sent)
}

func TestSendingBackend_OffersTheSameTransactionToTheNextEndpointWithinOneSend(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)
	first.err = errors.New("dial tcp: connect: connection refused")

	tx := testTx()
	require.NoError(t, b.SendTransaction(context.Background(), tx))

	// Failing over inside one send is safe precisely because it is the same signed transaction:
	// at most one endpoint can land it, so offering it twice is idempotent.
	require.Len(t, second.sent, 1)
	assert.Equal(t, tx.Hash(), second.sent[0].Hash())
	assert.Empty(t, public.sent, "a transient refusal must not fall straight through to public")
}

func TestSendingBackend_ReportsTheLastErrorRatherThanGoingPublic(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)
	first.err = errors.New("first is down")
	second.err = errors.New("second is down")

	err := b.SendTransaction(context.Background(), testTx())

	// The transaction manager above will bump and retry. Going public here would leak the claim on
	// the first blip rather than once the endpoints are established as down.
	require.ErrorContains(t, err, "second is down")
	assert.Empty(t, public.sent)
}

func TestSendingBackend_KeepsAnEndpointAfterASingleRefusal(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = rpcRejection{"failed to get tx into the mempool"}

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	// A relay that will not take one claim — one that would revert because a competitor already
	// processed the message — is still healthy for everything else.
	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_TripsAnEndpointOnlyAtTheFailureThreshold(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = errors.New("dial tcp: connect: connection refused")

	// Distinct transactions: an endpoint refusing everything it is handed is what being down
	// looks like, and that is the only thing that should trip it.
	for i := 1; i < DefaultPrivateRPCFailureThreshold; i++ {
		require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(uint64(i))))
		require.Equal(t, []int{0, 1}, b.inRotation(), "still in rotation after %d refusals", i)
	}

	require.NoError(t, b.SendTransaction(
		context.Background(),
		txWithNonce(uint64(DefaultPrivateRPCFailureThreshold)),
	))

	assert.Equal(t, []int{1}, b.inRotation())
}

func TestSendingBackend_RefusingTheSameTransactionAgainDoesNotTrip(t *testing.T) {
	b, public, first, _, _ := newTestBackend(t, nil)
	// What a relay does with a claim that would revert, because a competitor already processed
	// the message: it answers. The transaction manager resubmits the same transaction on its own,
	// so without per-transaction attribution one such claim would spend the endpoint's whole
	// budget.
	first.err = rpcRejection{"failed to get tx into the mempool"}

	tx := testTx()

	for i := 0; i < 3*DefaultPrivateRPCFailureThreshold; i++ {
		require.NoError(t, b.SendTransaction(context.Background(), tx))
	}

	assert.Equal(t, []int{0, 1}, b.inRotation(),
		"one claim a relay will not take must not cost it its turn for every other message")
	assert.Equal(t, 1, b.failures[0], "the same transaction is charged once, however often it is retried")
	assert.Empty(t, public.sent, "unrelated claims must not be pushed into the public mempool")
}

func TestSendingBackend_ChargesEachDistinctTransactionOnce(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = rpcRejection{"failed to get tx into the mempool"}

	// The same claim retried, then a different one: the second is new information about the
	// endpoint, the retries are not.
	for i := 0; i < 5; i++ {
		require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(1)))
	}

	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(2)))

	assert.Equal(t, 2, b.failures[0])
	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_GoesPublicOnlyOnceEveryEndpointIsTripped(t *testing.T) {
	b, public, _, _, _ := newTestBackend(t, nil)

	unavailableBefore := testutil.ToFloat64(relayer.PrivateRPCUnavailable)

	trip(b, 0)
	trip(b, 1)

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	assert.Len(t, public.sent, 1, "claims must still be sent when no private endpoint is up")
	assert.Equal(t, float64(1), testutil.ToFloat64(relayer.PrivateRPCUnavailable)-unavailableBefore,
		"running exposed has to be visible")
}

func TestSendingBackend_DoesNotCountPublicSendsWhenNoneIsConfigured(t *testing.T) {
	b := NewSendingBackend(&fakeBackend{}, nil, nil)

	before := testutil.ToFloat64(relayer.PrivateRPCUnavailable)

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	assert.Equal(t, before, testutil.ToFloat64(relayer.PrivateRPCUnavailable),
		"a relayer that configured no private endpoint is not degraded")
}

func TestSendingBackend_AttributesFailuresToTheEndpointThatRefused(t *testing.T) {
	b, _, first, second, _ := newTestBackend(t, nil)
	first.err = errors.New("first is down")
	second.err = errors.New("second is down")

	firstBefore := testutil.ToFloat64(relayer.PrivateRPCFailures.WithLabelValues("0"))
	secondBefore := testutil.ToFloat64(relayer.PrivateRPCFailures.WithLabelValues("1"))

	require.Error(t, b.SendTransaction(context.Background(), testTx()))

	assert.Equal(t, float64(1), testutil.ToFloat64(relayer.PrivateRPCFailures.WithLabelValues("0"))-firstBefore)
	assert.Equal(t, float64(1), testutil.ToFloat64(relayer.PrivateRPCFailures.WithLabelValues("1"))-secondBefore)
}

func TestSendingBackend_ASuccessfulSendReadmitsATrippedEndpoint(t *testing.T) {
	b, _, _, _, _ := newTestBackend(t, nil)

	trip(b, 0)
	require.Equal(t, []int{1}, b.inRotation())

	// An endpoint that just took a transaction is not down, whatever its recent record.
	b.recordSuccess(0, 1)

	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_ReturnsATrippedEndpointAfterTheRetryInterval(t *testing.T) {
	b, _, _, _, clock := newTestBackend(t, nil)

	trip(b, 0)

	*clock = clock.Add(DefaultPrivateRPCRetryInterval - time.Nanosecond)

	require.Equal(t, []int{1}, b.inRotation())

	*clock = clock.Add(time.Nanosecond)

	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_GivesARecoveredEndpointAFreshBudget(t *testing.T) {
	b, _, _, _, clock := newTestBackend(t, nil)

	trip(b, 0)

	*clock = clock.Add(DefaultPrivateRPCRetryInterval)

	require.Equal(t, []int{0, 1}, b.inRotation())

	// The spent count must not carry over, or the first refusal after recovery would trip it again.
	b.recordFailure(0, txWithNonce(99).Hash(), false)

	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_HonoursACustomRetryInterval(t *testing.T) {
	retryInterval := time.Minute
	b, _, _, _, clock := newTestBackend(t, &retryInterval)

	trip(b, 0)
	require.Equal(t, []int{1}, b.inRotation())

	*clock = clock.Add(retryInterval)

	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_UsesTheDefaultRetryIntervalWhenNoneIsUsable(t *testing.T) {
	zero := time.Duration(0)
	negative := -time.Minute

	for name, retryInterval := range map[string]*time.Duration{
		"nil":      nil,
		"zero":     &zero,
		"negative": &negative,
	} {
		t.Run(name, func(t *testing.T) {
			b := NewSendingBackend(&fakeBackend{}, []TxSender{&fakeSender{}}, retryInterval)

			assert.Equal(t, DefaultPrivateRPCRetryInterval, b.retryInterval)
		})
	}
}

func TestSendingBackend_CloseClosesEveryEndpoint(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)

	b.Close()

	assert.True(t, public.closed)
	assert.True(t, first.closed)
	assert.True(t, second.closed)
}

func TestSendingBackend_IsSafeUnderConcurrentUse(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = errors.New("intermittent")

	var wg sync.WaitGroup

	for i := 0; i < 50; i++ {
		wg.Add(1)

		go func() {
			defer wg.Done()

			_ = b.SendTransaction(context.Background(), testTx())
		}()
	}

	wg.Wait()
}

// hangingSender accepts the call and then never answers, which is the outage mode an immediate
// connection error does not model: it holds the context until the deadline runs out.
type hangingSender struct {
	mu       sync.Mutex
	attempts int
}

func (s *hangingSender) SendTransaction(ctx context.Context, _ *types.Transaction) error {
	s.mu.Lock()
	s.attempts++
	s.mu.Unlock()

	<-ctx.Done()

	return ctx.Err()
}

func (s *hangingSender) calls() int {
	s.mu.Lock()
	defer s.mu.Unlock()

	return s.attempts
}

// deadlineRecordingSender refuses a context that is already spent, and records how much time it
// was actually given.
type deadlineRecordingSender struct {
	mu        sync.Mutex
	gotLive   bool
	remaining time.Duration
	sent      []*types.Transaction
}

func (s *deadlineRecordingSender) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := ctx.Err(); err != nil {
		return err
	}

	if deadline, ok := ctx.Deadline(); ok {
		s.remaining = time.Until(deadline)
	}

	s.gotLive = true
	s.sent = append(s.sent, tx)

	return nil
}

func (s *deadlineRecordingSender) state() (bool, time.Duration, int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	return s.gotLive, s.remaining, len(s.sent)
}

func TestSendingBackend_AHangingEndpointDoesNotStarveTheNextOne(t *testing.T) {
	public := &fakeBackend{}
	first := &hangingSender{}
	second := &deadlineRecordingSender{}

	b := NewSendingBackend(public, []TxSender{first, second}, nil)

	ctx, cancel := context.WithTimeout(context.Background(), 400*time.Millisecond)
	defer cancel()

	require.NoError(t, b.SendTransaction(ctx, testTx()))

	gotLive, remaining, sent := second.state()

	// The first endpoint gets its share of the budget and no more, so the second still receives a
	// context it can use. Sharing one context would have handed it an expired one.
	assert.Equal(t, 1, first.calls())
	assert.True(t, gotLive, "the second endpoint must get a context with time left on it")
	assert.Positive(t, remaining)
	assert.Equal(t, 1, sent)
	assert.Empty(t, public.sent, "an endpoint that hangs must not push the claim into the mempool")

	// The endpoint that spent its whole share without answering is the one that failed; the one
	// that took the transaction is untouched.
	assert.Equal(t, []int{0, 1}, b.inRotation())
	assert.Equal(t, 1, b.failures[0])
	assert.Equal(t, 0, b.failures[1])
}

func TestSendingBackend_DoesNotCountEndpointsAgainstOurOwnDeadline(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)
	first.err = errors.New("first is down")
	second.err = errors.New("second is down")

	failuresBefore := testutil.ToFloat64(relayer.PrivateRPCFailures.WithLabelValues("1"))

	ctx, cancel := context.WithTimeout(context.Background(), time.Nanosecond)
	defer cancel()

	<-ctx.Done()

	require.Error(t, b.SendTransaction(ctx, testTx()))

	// The budget was gone before any endpoint was reached. Counting that against them would trip
	// healthy relays whenever the transaction manager's own timeout ran out.
	assert.Equal(t, []int{0, 1}, b.inRotation())
	assert.Equal(t, 0, b.failures[0])
	assert.Equal(t, 0, b.failures[1])
	assert.Equal(t, float64(0),
		testutil.ToFloat64(relayer.PrivateRPCFailures.WithLabelValues("1"))-failuresBefore)
	assert.Empty(t, public.sent)
}

func TestSendingBackend_GivesTheLastEndpointWhatIsLeft(t *testing.T) {
	public := &fakeBackend{}
	only := &deadlineRecordingSender{}

	b := NewSendingBackend(public, []TxSender{only}, nil)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	require.NoError(t, b.SendTransaction(ctx, testTx()))

	_, remaining, _ := only.state()

	// A single endpoint has nothing behind it, so carving the budget up would only shorten the
	// send for no reason.
	assert.Greater(t, remaining, 900*time.Millisecond)
}

func TestSendingBackend_KeepsCredentialsOutOfTheLog(t *testing.T) {
	// go-ethereum quotes the endpoint it was dialling, and these URLs carry API keys. The metrics
	// label by position for exactly this reason; the log must not undo that.
	redacted := redactURLs(errors.New(
		`Post "https://relay.example.com/v1/SUPERSECRETKEY?auth=alsosecret": dial tcp: i/o timeout`,
	))

	assert.NotContains(t, redacted, "SUPERSECRETKEY")
	assert.NotContains(t, redacted, "alsosecret")
	assert.NotContains(t, redacted, "relay.example.com")

	// The part that says what went wrong has to survive, or the log entry is worthless.
	assert.Contains(t, redacted, "i/o timeout")
}

func TestSendingBackend_CloseIsIdempotent(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)

	// The transaction manager closes its backend on shutdown, and the processor closes it too.
	b.Close()
	b.Close()

	assert.True(t, public.closed)
	assert.True(t, first.closed)
	assert.True(t, second.closed)
	assert.Equal(t, 1, public.closeCalls, "the underlying client must not be closed twice")
}

func TestSendingBackend_AnEndpointThatOnlyHangsStillTrips(t *testing.T) {
	public := &fakeBackend{}
	hanging := &hangingSender{}

	b := NewSendingBackend(public, []TxSender{hanging}, nil)

	unavailableBefore := testutil.ToFloat64(relayer.PrivateRPCUnavailable)

	// A sole private endpoint gets the whole budget, so spending it is also what exhausts the
	// caller's context. Checking the deadline after the send would read that as "our timeout, not
	// the relay's" and never charge it: the endpoint would hang forever, never trip, and claims
	// would keep timing out with no fallback and nothing to alert on.
	for i := 0; i < DefaultPrivateRPCFailureThreshold; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)

		require.Error(t, b.SendTransaction(ctx, txWithNonce(uint64(i))))

		cancel()
	}

	require.Equal(t, DefaultPrivateRPCFailureThreshold, hanging.calls())
	assert.Empty(t, b.inRotation(), "an endpoint that only ever hangs has to leave rotation")

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)
	defer cancel()

	require.NoError(t, b.SendTransaction(ctx, txWithNonce(99)))

	assert.Len(t, public.sent, 1, "claims must still go out once the endpoint is tripped")
	assert.Equal(t, float64(1),
		testutil.ToFloat64(relayer.PrivateRPCUnavailable)-unavailableBefore,
		"running exposed has to be visible")
}

func TestSendingBackend_RepeatedTimeoutsOnOneTransactionStillTrip(t *testing.T) {
	public := &fakeBackend{}
	hanging := &hangingSender{}

	b := NewSendingBackend(public, []TxSender{hanging}, nil)

	unavailableBefore := testutil.ToFloat64(relayer.PrivateRPCUnavailable)

	// The transaction manager republishes an *unchanged* transaction after a generic send error —
	// publishTx only bumps fees once a send succeeds — so a down endpoint sees the same hash for
	// as long as the claim lives. Deduplicating that would charge it once and leave it in rotation
	// forever, which is the outage this failover exists for.
	tx := txWithNonce(7)

	for i := 0; i < DefaultPrivateRPCFailureThreshold; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)

		require.Error(t, b.SendTransaction(ctx, tx))

		cancel()
	}

	assert.Empty(t, b.inRotation(), "repeated timeouts on one claim still have to trip the endpoint")

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)
	defer cancel()

	require.NoError(t, b.SendTransaction(ctx, tx))

	assert.Len(t, public.sent, 1, "the claim must reach the public endpoint once nothing is left")
	assert.Equal(t, float64(1),
		testutil.ToFloat64(relayer.PrivateRPCUnavailable)-unavailableBefore)
}

func TestSendingBackend_TransportFailuresOnOneTransactionStillTrip(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)

	// A dial failure is a net.Error, not an answer from the relay.
	down := &net.OpError{Op: "dial", Net: "tcp", Err: errors.New("connection refused")}
	first.err = down
	second.err = down

	tx := testTx()

	for i := 0; i < DefaultPrivateRPCFailureThreshold; i++ {
		require.Error(t, b.SendTransaction(context.Background(), tx))
	}

	assert.Empty(t, b.inRotation())

	require.NoError(t, b.SendTransaction(context.Background(), tx))
	assert.Len(t, public.sent, 1)
}

func Test_answeredWithRejection(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{
			// The relay answered: it is up, and has an opinion about this one transaction.
			name: "a JSON-RPC error response",
			err:  rpcRejection{"failed to get tx into the mempool"},
			want: true,
		},
		{
			name: "a JSON-RPC error wrapped in context",
			err:  fmt.Errorf("sending: %w", rpcRejection{"nonce too low"}),
			want: true,
		},
		{
			// No answer: these say nothing about the transaction and everything about the endpoint.
			name: "our deadline ran out",
			err:  context.DeadlineExceeded,
			want: false,
		},
		{name: "cancelled", err: context.Canceled, want: false},
		{
			name: "a dial failure",
			err:  &net.OpError{Op: "dial", Net: "tcp", Err: errors.New("connection refused")},
			want: false,
		},
		{
			name: "a bare error of unknown shape",
			err:  errors.New("something went wrong"),
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, answeredWithRejection(tt.err))
		})
	}
}

func TestSendingBackend_OffersAResentNonceToAnotherEndpointFirst(t *testing.T) {
	b, _, first, second, _ := newTestBackend(t, nil)

	tx := txWithNonce(5)

	require.NoError(t, b.SendTransaction(context.Background(), tx))
	require.Len(t, first.sent, 1)
	require.Empty(t, second.sent)

	// The transaction manager only re-sends a nonce it has not seen confirmed, so the first
	// endpoint took this one and did not get it included. Accepting is not inclusion, and the
	// replacement is better spent on a different builder than on the one that already had it.
	bumped := types.NewTx(&types.DynamicFeeTx{Nonce: 5, Gas: 21_000, GasTipCap: big.NewInt(2)})

	require.NoError(t, b.SendTransaction(context.Background(), bumped))

	assert.Len(t, second.sent, 1, "the replacement should go to the endpoint that has not had it")
	assert.Len(t, first.sent, 1)

	// Nothing is charged for this: non-inclusion is usually a fee or a lost race, and tripping on
	// it would push claims public for reasons that have nothing to do with the endpoint.
	assert.Equal(t, []int{0, 1}, b.inRotation())
	assert.Equal(t, 0, b.failures[0])

	// A different claim goes back to the configured order.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(6)))
	assert.Len(t, first.sent, 2)
}

func TestSendingBackend_ReturnedErrorsCarryNoEndpointURL(t *testing.T) {
	secret := "https://relay.example.com/v1/SUPERSECRETKEY?auth=alsosecret"

	b, _, first, second, _ := newTestBackend(t, nil)
	first.err = fmt.Errorf(`Post %q: dial tcp: i/o timeout`, secret)
	second.err = fmt.Errorf(`Post %q: dial tcp: i/o timeout`, secret)

	err := b.SendTransaction(context.Background(), testTx())

	// Redacting only our own log line is not enough: this error is returned to the transaction
	// manager, which logs it, and then to the processor, which logs it again. The redaction has to
	// travel with the error.
	require.Error(t, err)
	assert.NotContains(t, err.Error(), "SUPERSECRETKEY")
	assert.NotContains(t, err.Error(), "alsosecret")
	assert.NotContains(t, err.Error(), "relay.example.com")
	assert.Contains(t, err.Error(), "i/o timeout", "the reason has to survive")
}

func TestSendingBackend_PublicSendErrorsAreRedactedToo(t *testing.T) {
	public := &errBackend{err: fmt.Errorf(`Post %q: connection refused`, "https://eth.example.com/v2/PUBLICKEY")}

	b := NewSendingBackend(public, nil, nil)

	err := b.SendTransaction(context.Background(), testTx())

	// DEST_RPC_URL is just as likely to carry an API key as a relay URL is.
	require.Error(t, err)
	assert.NotContains(t, err.Error(), "PUBLICKEY")
	assert.Contains(t, err.Error(), "connection refused")
}

func TestSendingBackend_RedactionKeepsErrorIdentityAndClassification(t *testing.T) {
	sentinel := errors.New("nonce too low")
	only := &fakeSender{err: fmt.Errorf(`Post "https://relay.example.com/KEY": %w`, sentinel)}

	b := NewSendingBackend(&fakeBackend{}, []TxSender{only}, nil)

	err := b.SendTransaction(context.Background(), testTx())
	require.Error(t, err)

	// The transaction manager classifies send failures by matching substrings such as
	// "nonce too low" and by errors.Is, so redaction must not disturb either. Only URLs go.
	assert.ErrorIs(t, err, sentinel)
	assert.Contains(t, err.Error(), "nonce too low")
	assert.NotContains(t, err.Error(), "relay.example.com")
}

func TestSendingBackend_CapsAnAttemptWhenTheCallerGivesNoDeadline(t *testing.T) {
	// The transaction manager always supplies its NetworkTimeout, so this guards a direct caller
	// rather than the processor: without a cap, an endpoint that hangs would hold the send open
	// with no deadline to divide.
	ctx, cancel := attemptContext(context.Background(), 1)
	defer cancel()

	deadline, ok := ctx.Deadline()

	require.True(t, ok, "an attempt must always be bounded")
	assert.InDelta(t, DefaultPrivateRPCAttemptTimeout, time.Until(deadline), float64(time.Second))
}

func TestSendingBackend_KeepsTheResendRecordAcrossConcurrentNonces(t *testing.T) {
	b, _, first, second, _ := newTestBackend(t, nil)

	// The processor handles claims concurrently, so several nonces are in flight at once. A single
	// slot per endpoint would be overwritten by whichever was accepted most recently, and the
	// resend of the earlier one would go straight back to the endpoint that already had it.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(5)))
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(6)))
	require.Len(t, first.sent, 2)
	require.Empty(t, second.sent)

	// Nonce 5 is fee-bumped and resent. Endpoint 0 had it and did not get it included.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(5)))

	assert.Len(t, first.sent, 2, "the resend must not go back to the endpoint that already had it")
	assert.Len(t, second.sent, 1)

	// A claim newer than anything either endpoint has accepted goes back to the configured order.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(7)))
	assert.Len(t, first.sent, 3)
}

func TestSendingBackend_TheAcceptedMarkOnlyMovesForward(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)

	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(9)))
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(4)))

	// Accepting an out-of-order lower nonce must not lower the mark, or every resend at or below
	// the earlier high would silently become eligible for this endpoint again.
	assert.Equal(t, uint64(9), b.highestAccepted[0])
	assert.Len(t, first.sent, 1, "the lower nonce is at or below the mark, so it goes elsewhere")
}
