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
	"github.com/ethereum/go-ethereum/rpc"
	pkgerrors "github.com/pkg/errors"
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

// rotation is the endpoint order inRotation returned, without the admission generations, which
// only the send path has any use for.
func rotation(b *SendingBackend) []int {
	admitted := b.inRotation()
	indices := make([]int, 0, len(admitted))

	for _, endpoint := range admitted {
		indices = append(indices, endpoint.index)
	}

	return indices
}

// admit is the endpoint at index as a send taking a rotation snapshot right now would see it.
func admit(b *SendingBackend, index int) admission {
	b.mu.Lock()
	defer b.mu.Unlock()

	return admission{index: index, generation: b.generation[index]}
}

// trip refuses enough distinct transactions in a row to take a private endpoint out of rotation.
func trip(b *SendingBackend, index int) {
	for i := 0; i < DefaultPrivateRPCFailureThreshold; i++ {
		b.recordFailure(admit(b, index), txWithNonce(uint64(i)).Hash(), false)
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
	assert.Equal(t, []int{0, 1}, rotation(b))
}

func TestSendingBackend_TripsAnEndpointOnlyAtTheFailureThreshold(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = errors.New("dial tcp: connect: connection refused")

	// Distinct transactions: an endpoint refusing everything it is handed is what being down
	// looks like, and that is the only thing that should trip it.
	for i := 1; i < DefaultPrivateRPCFailureThreshold; i++ {
		require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(uint64(i))))
		require.Equal(t, []int{0, 1}, rotation(b), "still in rotation after %d refusals", i)
	}

	require.NoError(t, b.SendTransaction(
		context.Background(),
		txWithNonce(uint64(DefaultPrivateRPCFailureThreshold)),
	))

	assert.Equal(t, []int{1}, rotation(b))
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

	assert.Equal(t, []int{0, 1}, rotation(b),
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
	assert.Equal(t, []int{0, 1}, rotation(b))
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

func TestSendingBackend_CountsAcceptedTransactionsAgainstTheEndpointThatTookThem(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = errors.New("first is down")

	firstBefore := testutil.ToFloat64(relayer.PrivateRPCSends.WithLabelValues("0"))
	secondBefore := testutil.ToFloat64(relayer.PrivateRPCSends.WithLabelValues("1"))

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	assert.Equal(t, firstBefore, testutil.ToFloat64(relayer.PrivateRPCSends.WithLabelValues("0")),
		"an endpoint that refused the transaction did not accept it")
	assert.Equal(t, float64(1), testutil.ToFloat64(relayer.PrivateRPCSends.WithLabelValues("1"))-secondBefore,
		"the refusals are only readable as a rate against the sends the endpoint took")
}

func TestSendingBackend_ASuccessfulSendReadmitsATrippedEndpoint(t *testing.T) {
	b, _, _, _, _ := newTestBackend(t, nil)

	trip(b, 0)
	require.Equal(t, []int{1}, rotation(b))

	// An endpoint that just took a transaction is not down, whatever its recent record.
	b.recordSuccess(0, 1)

	assert.Equal(t, []int{0, 1}, rotation(b))
}

func TestSendingBackend_ReturnsATrippedEndpointAfterTheRetryInterval(t *testing.T) {
	b, _, _, _, clock := newTestBackend(t, nil)

	trip(b, 0)

	*clock = clock.Add(DefaultPrivateRPCRetryInterval - time.Nanosecond)

	require.Equal(t, []int{1}, rotation(b))

	*clock = clock.Add(time.Nanosecond)

	assert.Equal(t, []int{0, 1}, rotation(b))
}

func TestSendingBackend_GivesARecoveredEndpointAFreshBudget(t *testing.T) {
	b, _, _, _, clock := newTestBackend(t, nil)

	trip(b, 0)

	*clock = clock.Add(DefaultPrivateRPCRetryInterval)

	require.Equal(t, []int{0, 1}, rotation(b))

	// The spent count must not carry over, or the first refusal after recovery would trip it again.
	b.recordFailure(admit(b, 0), txWithNonce(99).Hash(), false)

	assert.Equal(t, []int{0, 1}, rotation(b))
}

func TestSendingBackend_HonoursACustomRetryInterval(t *testing.T) {
	retryInterval := time.Minute
	b, _, _, _, clock := newTestBackend(t, &retryInterval)

	trip(b, 0)
	require.Equal(t, []int{1}, rotation(b))

	*clock = clock.Add(retryInterval)

	assert.Equal(t, []int{0, 1}, rotation(b))
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

	ctx, cancel := context.WithTimeout(context.Background(), 1200*time.Millisecond)
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
	assert.Equal(t, []int{0, 1}, rotation(b))
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
	assert.Equal(t, []int{0, 1}, rotation(b))
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
		ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)

		require.Error(t, b.SendTransaction(ctx, txWithNonce(uint64(i))))

		cancel()
	}

	require.Equal(t, DefaultPrivateRPCFailureThreshold, hanging.calls())
	assert.Empty(t, rotation(b), "an endpoint that only ever hangs has to leave rotation")

	ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)
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
		ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)

		require.Error(t, b.SendTransaction(ctx, tx))

		cancel()
	}

	assert.Empty(t, rotation(b), "repeated timeouts on one claim still have to trip the endpoint")

	ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)
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

	assert.Empty(t, rotation(b))

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
			// go-ethereum surfaces a non-2xx HTTP response as rpc.HTTPError, which carries a
			// status code but no ErrorCode and therefore does not satisfy rpc.Error. That is the
			// right answer: a 429 or a 502 is the relay's health, not an opinion about this one
			// transaction, so it must count every time rather than be deduplicated per claim.
			name: "a rate limit",
			err:  rpc.HTTPError{StatusCode: 429, Status: "429 Too Many Requests"},
			want: false,
		},
		{
			name: "a gateway error wrapped in context",
			err:  fmt.Errorf("sending: %w", rpc.HTTPError{StatusCode: 502, Status: "502 Bad Gateway"}),
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
	assert.Equal(t, []int{0, 1}, rotation(b))
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

	// This repository also uses github.com/pkg/errors, which reaches for Cause rather than
	// following Unwrap, so the wrapper has to answer both.
	assert.ErrorIs(t, pkgerrors.Cause(err), sentinel)

	// Cause walks the whole chain in one call and exists to be inspected and logged, which makes
	// it the likeliest way for an endpoint URL to reach a log by accident. It — and the first step
	// out of the wrapper by Unwrap, which had the same hole — must still print redacted.
	for name, step := range map[string]error{
		"Cause":  pkgerrors.Cause(err),
		"Unwrap": errors.Unwrap(err),
	} {
		require.Error(t, step, name)

		assert.NotContains(t, step.Error(), "relay.example.com", name)
		assert.NotContains(t, fmt.Sprintf("%#v", step), "relay.example.com", name)
		assert.Contains(t, step.Error(), "nonce too low", name)
		assert.ErrorIs(t, step, sentinel, name)
	}
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

func TestSendingBackend_AnEndpointRefusingEverythingStepsAside(t *testing.T) {
	public := &fakeBackend{}
	// A relay answering every attempt with a JSON-RPC error — an internal error, a missing method
	// — is broken endpoint-wide, but to the per-transaction deduplication it looks exactly like a
	// relay declining one claim. The transaction manager resends the same hash every
	// RESUBMISSION_TIMEOUT, so without a ceiling this endpoint would hold its place indefinitely.
	broken := &fakeSender{err: rpcRejection{"internal error"}}

	b := NewSendingBackend(public, []TxSender{broken}, nil)

	unavailableBefore := testutil.ToFloat64(relayer.PrivateRPCUnavailable)

	tx := txWithNonce(7)

	for i := 0; i < DefaultPrivateRPCConsecutiveFailureCeiling; i++ {
		require.Error(t, b.SendTransaction(context.Background(), tx))
	}

	assert.Empty(t, rotation(b), "refusing everything in a row has to cost the endpoint its place")

	require.NoError(t, b.SendTransaction(context.Background(), tx))

	assert.Len(t, public.sent, 1)
	assert.Equal(t, float64(1),
		testutil.ToFloat64(relayer.PrivateRPCUnavailable)-unavailableBefore)
}

func TestSendingBackend_ASuccessResetsTheConsecutiveCount(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = rpcRejection{"failed to get tx into the mempool"}

	tx := testTx()

	// Just short of the ceiling, then one the endpoint takes.
	for i := 0; i < DefaultPrivateRPCConsecutiveFailureCeiling-1; i++ {
		require.NoError(t, b.SendTransaction(context.Background(), tx))
	}

	first.err = nil

	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(99)))

	first.err = rpcRejection{"failed to get tx into the mempool"}

	// The run is broken, so the count starts again rather than tripping on the next refusal.
	require.NoError(t, b.SendTransaction(context.Background(), tx))
	assert.Equal(t, []int{0, 1}, rotation(b))
	assert.Equal(t, 1, b.consecutive[0])
}

func TestSendingBackend_DoesNotChargeAnEndpointForOurExpiredBudget(t *testing.T) {
	b, public, first, second, _ := newTestBackend(t, nil)
	first.err = errors.New("should never be reached")

	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
	defer cancel()

	// The budget is gone before any endpoint gets a usable context. Checking the attempt's own
	// context rather than the parent's also covers the parent expiring between the two, which is
	// how a healthy endpoint could otherwise be charged for our timeout.
	require.Error(t, b.SendTransaction(ctx, testTx()))

	assert.Empty(t, first.sent)
	assert.Empty(t, second.sent)
	assert.Empty(t, public.sent)
	assert.Equal(t, []int{0, 1}, rotation(b))
	assert.Equal(t, 0, b.failures[0])
	assert.Equal(t, 0, b.consecutive[0])
}

func TestSendingBackend_DoesNotCountAPublicBroadcastThatFailed(t *testing.T) {
	public := &errBackend{err: errors.New("dial tcp: connect: connection refused")}
	b := NewSendingBackend(public, []TxSender{&fakeSender{}}, nil)

	trip(b, 0)
	require.Empty(t, rotation(b))

	before := testutil.ToFloat64(relayer.PrivateRPCUnavailable)

	require.Error(t, b.SendTransaction(context.Background(), testTx()))

	// A send that failed against our own node never reached the mempool, so counting it would
	// overstate the exposure this metric exists to alert on.
	assert.Equal(t, before, testutil.ToFloat64(relayer.PrivateRPCUnavailable))
}

// cancellingSender cancels the caller's context and reports that, standing in for a send abandoned
// from our side — a shutdown, or the transaction manager giving up — rather than refused by the
// relay.
type cancellingSender struct {
	mu     sync.Mutex
	cancel context.CancelFunc
	calls  int
}

func (s *cancellingSender) SendTransaction(_ context.Context, _ *types.Transaction) error {
	s.mu.Lock()
	s.calls++
	s.mu.Unlock()

	s.cancel()

	return context.Canceled
}

func TestSendingBackend_DoesNotChargeAnEndpointForOurCancellation(t *testing.T) {
	public := &fakeBackend{}
	first := &cancellingSender{}
	second := &fakeSender{}

	b := NewSendingBackend(public, []TxSender{first, second}, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	first.cancel = cancel

	require.ErrorIs(t, b.SendTransaction(ctx, testTx()), context.Canceled)

	// A cancel only ever comes from the caller, unlike a deadline an endpoint can exhaust by going
	// quiet. Charging for it would trip healthy relays on every shutdown.
	assert.Equal(t, 1, first.calls)
	assert.Equal(t, []int{0, 1}, rotation(b))
	assert.Equal(t, 0, b.failures[0])
	assert.Equal(t, 0, b.consecutive[0])
	assert.Empty(t, public.sent)
}

// stubbornSender overruns its share of the budget and only then answers with a rejection.
//
// It ignores the context on purpose. Not every step of a send watches one — a blocking DNS lookup
// or a slow TLS handshake will not — so an endpoint can spend more than the share it was given and
// still come back with an answer. That is the case where the send concluded but the endpoints
// behind it no longer have any time to be asked.
type stubbornSender struct {
	delay time.Duration

	mu   sync.Mutex
	sent []common.Hash
}

func (s *stubbornSender) SendTransaction(_ context.Context, tx *types.Transaction) error {
	s.mu.Lock()
	s.sent = append(s.sent, tx.Hash())
	s.mu.Unlock()

	time.Sleep(s.delay)

	return rpcRejection{"execution reverted"}
}

func TestSendingBackend_ARejectionDoesNotMaskAnExpiredBudget(t *testing.T) {
	slow := &stubbornSender{delay: 400 * time.Millisecond}
	second := &fakeSender{}

	b := NewSendingBackend(&fakeBackend{}, []TxSender{slow, second}, nil)

	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()

	err := b.SendTransaction(ctx, testTx())
	require.Error(t, err)

	// The first endpoint answered, but only after the budget the second one needed. Returning its
	// rejection would describe a send whose remaining endpoint was never asked, and the processor
	// classifies on what comes back: "execution reverted" is not transient, so the claim would be
	// dropped instead of retried. Running out of time is.
	assert.ErrorIs(t, err, context.DeadlineExceeded)
	assert.NotContains(t, err.Error(), "execution reverted")

	assert.Len(t, slow.sent, 1)
	assert.Empty(t, second.sent, "there was no budget left to offer it")

	// The endpoint that hung still earned its failure; the one that never got a context did not.
	assert.Equal(t, 1, b.failures[0])
	assert.Equal(t, 0, b.failures[1])
}

func TestSendingBackend_GoSyntaxPrintingCarriesNoEndpointURL(t *testing.T) {
	secret := "https://relay.example.com/v1/SUPERSECRETKEY"
	only := &fakeSender{err: fmt.Errorf(`Post %q: dial tcp: i/o timeout`, secret)}

	b := NewSendingBackend(&fakeBackend{}, []TxSender{only}, nil)

	err := b.SendTransaction(context.Background(), testTx())
	require.Error(t, err)

	// %v and %s go through Error, but %#v prints the struct's fields, and the field is the
	// unredacted error. A logger reaching for a Go-syntax dump must not be the hole.
	for _, verb := range []string{"%v", "%s", "%q", "%#v", "%+v", "%d"} {
		printed := fmt.Sprintf(verb, err)

		assert.NotContains(t, printed, "SUPERSECRETKEY", verb)
		assert.NotContains(t, printed, "relay.example.com", verb)
	}

	assert.Contains(t, fmt.Sprintf("%#v", err), "i/o timeout", "the reason still has to survive")
}

func TestSendingBackend_CountsLeavingTheRotationOnceRatherThanEveryRefusal(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = errors.New("down")

	before := testutil.ToFloat64(relayer.PrivateRPCTrips.WithLabelValues("0"))
	trips := func() float64 {
		return testutil.ToFloat64(relayer.PrivateRPCTrips.WithLabelValues("0")) - before
	}

	// Refusals below the threshold are counted by PrivateRPCFailures, not by this. Leaving the
	// rotation is a different event: one fewer place to send privately, which is what an operator
	// alerts on.
	for nonce := uint64(1); nonce < DefaultPrivateRPCFailureThreshold; nonce++ {
		require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(nonce)))
		assert.Zero(t, trips(), "still in rotation after %d refusals", nonce)
	}

	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(DefaultPrivateRPCFailureThreshold)))

	assert.Equal(t, float64(1), trips())
	assert.Equal(t, []int{1}, rotation(b))

	// Out of rotation, it is not asked again, so the count does not keep climbing.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(99)))
	assert.Equal(t, float64(1), trips())
}

// gatedSender holds every send inside the endpoint until the test releases it by nonce, so two
// sends can be made to overlap on one endpoint at a chosen point in each other's progress. That is
// what the processor does routinely — it claims several messages at once — and what a snapshot of
// the rotation taken per send exposes to.
type gatedSender struct {
	entered chan uint64
	release map[uint64]chan struct{}
	err     error
}

// newGatedSender gates the given nonces. The release channels are all created up front, so the map
// is only ever read once a send is in flight.
func newGatedSender(err error, nonces ...uint64) *gatedSender {
	s := &gatedSender{
		entered: make(chan uint64, len(nonces)),
		release: make(map[uint64]chan struct{}, len(nonces)),
		err:     err,
	}

	for _, nonce := range nonces {
		s.release[nonce] = make(chan struct{})
	}

	return s
}

func (s *gatedSender) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	s.entered <- tx.Nonce()

	select {
	case <-s.release[tx.Nonce()]:
		return s.err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// newGatedBackend builds a backend whose first private endpoint is gated and whose second is
// ordinary, with a clock the test moves by hand. The clock is only written while every send is
// parked in the gate, so the channel handover orders it against the sends' own reads.
func newGatedBackend(gate *gatedSender, second *fakeSender) (*SendingBackend, *time.Time) {
	now := time.Date(2026, time.August, 29, 0, 0, 0, 0, time.UTC)

	b := NewSendingBackend(&fakeBackend{}, []TxSender{gate, second}, nil)
	b.now = func() time.Time { return now }

	return b, &now
}

func TestSendingBackend_AConcurrentFailureFromTheSameSnapshotDoesNotRetrip(t *testing.T) {
	gate := newGatedSender(errors.New("down"), 1, 2)
	b, clock := newGatedBackend(gate, &fakeSender{err: errors.New("down")})
	tripped := *clock

	before := testutil.ToFloat64(relayer.PrivateRPCTrips.WithLabelValues("0"))
	trips := func() float64 {
		return testutil.ToFloat64(relayer.PrivateRPCTrips.WithLabelValues("0")) - before
	}

	// One refusal short of the threshold, so the next failure is the one that costs the endpoint
	// its place.
	for i := 0; i < DefaultPrivateRPCFailureThreshold-1; i++ {
		b.recordFailure(admit(b, 0), txWithNonce(uint64(100+i)).Hash(), false)
	}

	// Both sends take their rotation snapshot and reach the endpoint before either has a result, so
	// both were admitted while it was still healthy.
	done := make(chan uint64, 2)

	for _, nonce := range []uint64{1, 2} {
		go func(nonce uint64) {
			_ = b.SendTransaction(context.Background(), txWithNonce(nonce))

			done <- nonce
		}(nonce)
	}

	require.NotEqual(t, <-gate.entered, <-gate.entered, "both sends have to be inside the endpoint")

	// The first result to come back trips the endpoint.
	close(gate.release[1])
	require.Equal(t, uint64(1), <-done)

	require.Equal(t, float64(1), trips())
	require.Equal(t, []int{1}, rotation(b))

	// The second comes back a minute later, from the snapshot taken before that trip.
	*clock = tripped.Add(time.Minute)

	close(gate.release[2])
	require.Equal(t, uint64(2), <-done)

	assert.Equal(t, float64(1), trips(), "one outage is one departure, however many sends it caught")
	assert.Equal(t, tripped, b.failedAt[0],
		"the retry interval runs from the trip, not from the last straggler to come back")

	// So the endpoint is due back a retry interval after it left. Charging the straggler again would
	// have pushed that out by a minute — and by a minute per send still in flight when it went down,
	// which under sustained load is how a recovered endpoint stays out for far longer than the
	// interval an operator configured.
	*clock = tripped.Add(DefaultPrivateRPCRetryInterval)

	assert.Equal(t, []int{0, 1}, rotation(b))
}

func TestSendingBackend_AFailureOutlivingATripDoesNotSpendTheFreshBudget(t *testing.T) {
	gate := newGatedSender(errors.New("down"), 1)
	b, clock := newGatedBackend(gate, &fakeSender{})
	start := *clock

	done := make(chan struct{})

	go func() {
		_ = b.SendTransaction(context.Background(), txWithNonce(1))

		close(done)
	}()

	require.Equal(t, uint64(1), <-gate.entered)

	// While that send sits in the gate the endpoint goes down, leaves the rotation, and is let back
	// in with a clean budget once the retry interval has passed.
	trip(b, 0)
	require.Equal(t, []int{1}, rotation(b))

	*clock = start.Add(DefaultPrivateRPCRetryInterval)

	require.Equal(t, []int{0, 1}, rotation(b))

	// Only now does the send from before the trip come back. Its failure is evidence about the
	// outage that is over, not about the endpoint that was just re-admitted, so it buys none of the
	// budget the re-admission handed out.
	close(gate.release[1])
	<-done

	assert.Zero(t, b.failures[0])
	assert.Zero(t, b.consecutive[0])
	assert.Equal(t, []int{0, 1}, rotation(b))
}

func TestSendingBackend_KeepsTheAcceptedMarkAcrossATrip(t *testing.T) {
	b, _, first, second, clock := newTestBackend(t, nil)

	// The first endpoint takes nonce 5, then goes down and leaves the rotation.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(5)))
	require.Len(t, first.sent, 1)

	first.err = errors.New("down")

	trip(b, 0)
	require.Equal(t, []int{1}, rotation(b))

	*clock = clock.Add(DefaultPrivateRPCRetryInterval)
	first.err = nil

	require.Equal(t, []int{0, 1}, rotation(b))

	// Re-admission clears the failure record but not what the endpoint has already accepted. A
	// resend of nonce 5 is still better offered elsewhere first: endpoint 0 may well be holding
	// that transaction, and handing it back is the duplicate the mark exists to avoid.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(5)))

	assert.Len(t, first.sent, 1, "the resend went elsewhere")
	assert.Len(t, second.sent, 1)

	// A nonce above the mark is unaffected — it goes to the first endpoint as usual.
	require.NoError(t, b.SendTransaction(context.Background(), txWithNonce(6)))
	assert.Len(t, first.sent, 2)
}
