package utils

import (
	"context"
	"errors"
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

func (f *fakeBackend) Close() { f.closed = true }

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

func testTx() *types.Transaction {
	return types.NewTx(&types.DynamicFeeTx{Nonce: 7, Gas: 21_000})
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

// trip refuses enough sends in a row to take a private endpoint out of rotation.
func trip(b *SendingBackend, index int) {
	for i := 0; i < DefaultPrivateRPCFailureThreshold; i++ {
		b.recordFailure(index)
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
	first.err = errors.New("failed to get tx into the mempool")

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	// A relay that will not take one claim — one that would revert because a competitor already
	// processed the message — is still healthy for everything else.
	assert.Equal(t, []int{0, 1}, b.inRotation())
}

func TestSendingBackend_TripsAnEndpointOnlyAtTheFailureThreshold(t *testing.T) {
	b, _, first, _, _ := newTestBackend(t, nil)
	first.err = errors.New("dial tcp: connect: connection refused")

	for i := 1; i < DefaultPrivateRPCFailureThreshold; i++ {
		require.NoError(t, b.SendTransaction(context.Background(), testTx()))
		require.Equal(t, []int{0, 1}, b.inRotation(), "still in rotation after %d refusals", i)
	}

	require.NoError(t, b.SendTransaction(context.Background(), testTx()))

	assert.Equal(t, []int{1}, b.inRotation())
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
	b.recordSuccess(0)

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
	b.recordFailure(0)

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
