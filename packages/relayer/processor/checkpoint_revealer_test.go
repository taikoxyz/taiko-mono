package processor

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/anchor"
)

var (
	testAnchorAddress          = common.HexToAddress("0x1670000000000000000000000000000000010001")
	testCheckpointStoreAddress = common.HexToAddress("0x1670000000000000000000000000000000000005")
)

// fakeHeaders serves headers by number and by hash and counts the reads. HeaderByNumber(nil)
// returns the head.
type fakeHeaders struct {
	head     uint64
	byNumber map[uint64]*types.Header
	byHash   map[common.Hash]*types.Header
	reads    atomic.Int32
}

func (f *fakeHeaders) HeaderByNumber(_ context.Context, number *big.Int) (*types.Header, error) {
	f.reads.Add(1)

	n := f.head
	if number != nil {
		n = number.Uint64()
	}

	header, ok := f.byNumber[n]
	if !ok {
		return nil, ethereum.NotFound
	}

	return header, nil
}

func (f *fakeHeaders) HeaderByHash(_ context.Context, hash common.Hash) (*types.Header, error) {
	f.reads.Add(1)

	header, ok := f.byHash[hash]
	if !ok {
		return nil, ethereum.NotFound
	}

	return header, nil
}

// fakeTxSender records what it is asked to send and answers with a fixed receipt and error. When
// release is set, Send reports on sending and then waits for release.
type fakeTxSender struct {
	mu         sync.Mutex
	candidates []txmgr.TxCandidate
	receipt    *types.Receipt
	err        error
	sending    chan struct{}
	release    chan struct{}
}

func (s *fakeTxSender) Send(_ context.Context, candidate txmgr.TxCandidate) (*types.Receipt, error) {
	s.mu.Lock()
	s.candidates = append(s.candidates, candidate)
	s.mu.Unlock()

	if s.release != nil {
		s.sending <- struct{}{}
		<-s.release
	}

	return s.receipt, s.err
}

func (s *fakeTxSender) sent() []txmgr.TxCandidate {
	s.mu.Lock()
	defer s.mu.Unlock()

	return append([]txmgr.TxCandidate(nil), s.candidates...)
}

// fakeAnchorCaller answers checkpointStore() the way an Anchor, or a contract without it, would.
type fakeAnchorCaller struct {
	store common.Address
	err   error
}

func (c fakeAnchorCaller) CheckpointStore(*bind.CallOpts) (common.Address, error) {
	return c.store, c.err
}

// fakeClock is a time source the tests move by hand.
type fakeClock struct {
	now time.Time
}

func (c *fakeClock) Now() time.Time {
	return c.now
}

// testL1Header returns a post-Prague L1 header carrying every optional field mainnet headers have.
func testL1Header(number uint64) *types.Header {
	withdrawalsHash := types.EmptyWithdrawalsHash
	blobGasUsed := uint64(0x60000)
	excessBlobGas := uint64(0xabf3cc3)
	parentBeaconRoot := common.HexToHash("0x09bd245dfbaba20162a7b64d8c0096e8ce1b4a2356a02b159c972c6dbcbeff4a")
	requestsHash := types.EmptyRequestsHash

	return &types.Header{
		ParentHash:       common.HexToHash("0xa3fc44ef542609fa1b14af94dba91479f2ab643d13e985cf4860961c2320d812"),
		UncleHash:        types.EmptyUncleHash,
		Coinbase:         common.HexToAddress("0x396343362be2a4da1ce0c1c210945346fb82aa49"),
		Root:             common.HexToHash("0xa9b8f0813627091b7d1e7c1b4a199956944e44cb1a832a33dbc0e3408fc888bd"),
		TxHash:           types.EmptyTxsHash,
		ReceiptHash:      types.EmptyReceiptsHash,
		Difficulty:       common.Big0,
		Number:           new(big.Int).SetUint64(number),
		GasLimit:         60_000_000,
		GasUsed:          21_000,
		Time:             1_790_000_000,
		Extra:            []byte("relayer test"),
		BaseFee:          big.NewInt(79_154_171),
		WithdrawalsHash:  &withdrawalsHash,
		BlobGasUsed:      &blobGasUsed,
		ExcessBlobGas:    &excessBlobGas,
		ParentBeaconRoot: &parentBeaconRoot,
		RequestsHash:     &requestsHash,
	}
}

// testL2Header returns an L2 header anchored to the L1 block whose hash is root.
func testL2Header(number, timestamp uint64, root *common.Hash) *types.Header {
	return &types.Header{
		Number:           new(big.Int).SetUint64(number),
		Time:             timestamp,
		ParentBeaconRoot: root,
	}
}

// revealerFixture is a revealer over an L2 chain whose head is block 10 at timestamp 1,020, and
// whose settled block 9, at timestamp 1,018, anchors L1 block l1Header.
type revealerFixture struct {
	revealer *checkpointRevealer
	src      *fakeHeaders
	dest     *fakeHeaders
	sender   *fakeTxSender
	clock    *fakeClock
	l1Header *types.Header
	root     common.Hash
}

func newRevealerFixture(t *testing.T, l1Number uint64) *revealerFixture {
	t.Helper()

	l1Header := testL1Header(l1Number)
	root := l1Header.Hash()

	src := &fakeHeaders{byHash: map[common.Hash]*types.Header{root: l1Header}}
	dest := &fakeHeaders{
		head: 10,
		byNumber: map[uint64]*types.Header{
			9:  testL2Header(9, 1_018, &root),
			10: testL2Header(10, 1_020, &root),
		},
	}
	sender := &fakeTxSender{receipt: &types.Receipt{
		Status: types.ReceiptStatusSuccessful,
		TxHash: common.HexToHash("0xbeef"),
	}}
	clock := &fakeClock{now: time.Unix(1_790_000_000, 0)}

	revealer, err := newCheckpointRevealer(
		context.Background(),
		testAnchorAddress,
		fakeAnchorCaller{store: testCheckpointStoreAddress},
		src,
		dest,
		sender,
		6*time.Second,
	)
	require.NoError(t, err)

	revealer.now = clock.Now

	return &revealerFixture{
		revealer: revealer,
		src:      src,
		dest:     dest,
		sender:   sender,
		clock:    clock,
		l1Header: l1Header,
		root:     root,
	}
}

// unpackRevealCheckpoint returns the arguments of a revealCheckpoint call.
func unpackRevealCheckpoint(t *testing.T, data []byte) (uint64, []byte) {
	t.Helper()

	anchorABI, err := anchor.AnchorMetaData.GetAbi()
	require.NoError(t, err)

	method := anchorABI.Methods["revealCheckpoint"]
	require.Equal(t, method.ID, data[:4])

	args, err := method.Inputs.Unpack(data[4:])
	require.NoError(t, err)

	l2Timestamp, ok := args[0].(uint64)
	require.True(t, ok)

	headerRlp, ok := args[1].([]byte)
	require.True(t, ok)

	return l2Timestamp, headerRlp
}

func TestNewCheckpointRevealerRequiresAnAnchor(t *testing.T) {
	ctx := context.Background()

	// The L1 Inbox, which an L2 to L1 processor has as its destTaikoAddress, has no
	// checkpointStore(), so the call reverts.
	_, err := newCheckpointRevealer(
		ctx, testAnchorAddress, fakeAnchorCaller{err: errors.New("execution reverted")}, nil, nil, nil, time.Second,
	)
	require.ErrorContains(t, err, "is not an Anchor")

	_, err = newCheckpointRevealer(ctx, testAnchorAddress, fakeAnchorCaller{}, nil, nil, nil, time.Second)
	require.ErrorContains(t, err, "has no checkpoint store")

	revealer, err := newCheckpointRevealer(
		ctx, testAnchorAddress, fakeAnchorCaller{store: testCheckpointStoreAddress}, nil, nil, nil, time.Second,
	)
	require.NoError(t, err)
	assert.Equal(t, testAnchorAddress, revealer.anchor)
	assert.Equal(t, time.Second, revealer.interval)
	assert.Equal(t, checkpointRevealRetryAfter, revealer.retryAfter)
}

func TestCheckpointRevealerWaitsBeforeEtna(t *testing.T) {
	for name, root := range map[string]*common.Hash{"nil root": nil, "zero root": {}} {
		t.Run(name, func(t *testing.T) {
			f := newRevealerFixture(t, 100)
			f.dest.byNumber[9] = testL2Header(9, 1_018, root)

			// Before Etna the anchor transaction saves the checkpoint, so there is nothing to send.
			require.NoError(t, f.revealer.reveal(context.Background(), 100))
			assert.Empty(t, f.sender.sent())
			assert.Zero(t, f.src.reads.Load())
		})
	}
}

func TestCheckpointRevealerWaitsUntilTheBlockIsAnchored(t *testing.T) {
	f := newRevealerFixture(t, 100)

	// L2 anchors L1 block 100 and the message is in block 101, so no reveal can cover it yet.
	require.NoError(t, f.revealer.reveal(context.Background(), 101))
	assert.Empty(t, f.sender.sent())
}

func TestCheckpointRevealerSendsTheAnchoredHeader(t *testing.T) {
	f := newRevealerFixture(t, 100)
	revealsBefore := testutil.ToFloat64(relayer.CheckpointRevealsSent)

	require.NoError(t, f.revealer.reveal(context.Background(), 95))

	sent := f.sender.sent()
	require.Len(t, sent, 1)
	require.NotNil(t, sent[0].To)
	assert.Equal(t, testAnchorAddress, *sent[0].To)
	assert.Zero(t, sent[0].GasLimit, "the tx manager has to estimate gas, so a reveal that would revert costs nothing")

	l2Timestamp, headerRlp := unpackRevealCheckpoint(t, sent[0].TxData)
	assert.Equal(t, uint64(1_018), l2Timestamp)
	assert.Equal(t, f.root, crypto.Keccak256Hash(headerRlp))

	var decoded types.Header

	require.NoError(t, rlp.DecodeBytes(headerRlp, &decoded))
	assert.Equal(t, uint64(100), decoded.Number.Uint64())

	assert.Equal(t, uint64(100), f.revealer.revealed)
	assert.Equal(t, revealsBefore+1, testutil.ToFloat64(relayer.CheckpointRevealsSent))
}

func TestCheckpointRevealerSkipsBlocksSharingTheHeadTimestamp(t *testing.T) {
	f := newRevealerFixture(t, 100)

	newer := testL1Header(101)
	newerRoot := newer.Hash()
	f.src.byHash[newerRoot] = newer

	// Block 9 shares the head's timestamp, so a later block could still overwrite its EIP-4788
	// slot before the reveal lands. Block 8 is the newest block whose slot is settled.
	f.dest.byNumber[9] = testL2Header(9, 1_020, &newerRoot)
	f.dest.byNumber[8] = testL2Header(8, 1_016, &f.root)

	require.NoError(t, f.revealer.reveal(context.Background(), 100))

	sent := f.sender.sent()
	require.Len(t, sent, 1)

	l2Timestamp, headerRlp := unpackRevealCheckpoint(t, sent[0].TxData)
	assert.Equal(t, uint64(1_016), l2Timestamp)
	assert.Equal(t, f.root, crypto.Keccak256Hash(headerRlp))
}

func TestCheckpointRevealerNeedsABlockBelowTheHeadTimestamp(t *testing.T) {
	f := newRevealerFixture(t, 100)
	f.dest.head = 1
	f.dest.byNumber[0] = testL2Header(0, 1_000, &f.root)
	f.dest.byNumber[1] = testL2Header(1, 1_000, &f.root)

	err := f.revealer.reveal(context.Background(), 100)
	require.ErrorContains(t, err, "has a lower timestamp")
	assert.Empty(t, f.sender.sent())
}

func TestCheckpointRevealerWaitsForAPendingReveal(t *testing.T) {
	f := newRevealerFixture(t, 100)
	ctx := context.Background()

	require.NoError(t, f.revealer.reveal(ctx, 100))

	// Past the attempt interval but inside retryAfter: the reveal of block 100 covers block 90 and
	// is still on its way to the index.
	f.clock.now = f.clock.now.Add(time.Minute)
	require.NoError(t, f.revealer.reveal(ctx, 90))
	assert.Len(t, f.sender.sent(), 1)

	// A reveal that has not been indexed after retryAfter was most likely reorged out.
	f.clock.now = f.clock.now.Add(checkpointRevealRetryAfter)
	require.NoError(t, f.revealer.reveal(ctx, 90))
	assert.Len(t, f.sender.sent(), 2)
}

func TestCheckpointRevealerAttemptsAtMostOncePerInterval(t *testing.T) {
	f := newRevealerFixture(t, 100)
	ctx := context.Background()

	// Not anchored yet: the attempt reads headers and sends nothing.
	require.NoError(t, f.revealer.reveal(ctx, 101))

	reads := f.dest.reads.Load()
	require.NotZero(t, reads)

	// Every waiting message asks on every tick. Within the interval none of them reach the node.
	f.clock.now = f.clock.now.Add(5 * time.Second)
	require.NoError(t, f.revealer.reveal(ctx, 101))
	assert.Equal(t, reads, f.dest.reads.Load())

	f.clock.now = f.clock.now.Add(time.Second)
	require.NoError(t, f.revealer.reveal(ctx, 101))
	assert.Greater(t, f.dest.reads.Load(), reads)
}

func TestCheckpointRevealerDoesNotWaitForAnotherAttempt(t *testing.T) {
	f := newRevealerFixture(t, 100)
	f.sender.sending = make(chan struct{})
	f.sender.release = make(chan struct{})

	done := make(chan error, 1)

	go func() {
		done <- f.revealer.reveal(context.Background(), 100)
	}()

	<-f.sender.sending

	// The first attempt is still sending. The others return at once instead of queueing behind it,
	// and their messages keep polling the index, where the first reveal will show up.
	for range 10 {
		require.NoError(t, f.revealer.reveal(context.Background(), 100))
	}

	close(f.sender.release)

	require.NoError(t, <-done)
	assert.Len(t, f.sender.sent(), 1)
}

func TestCheckpointRevealerRefusesAHeaderItCannotReproduce(t *testing.T) {
	f := newRevealerFixture(t, 100)

	// The node finds the block by its hash, but the header it returns no longer hashes to it, as
	// when L1 adds a header field this go-ethereum does not know.
	altered := testL1Header(100)
	altered.Extra = []byte("a field the client dropped")
	f.src.byHash[f.root] = altered

	err := f.revealer.reveal(context.Background(), 100)
	require.ErrorContains(t, err, "cannot reproduce the encoding")
	assert.Empty(t, f.sender.sent())
}

func TestCheckpointRevealerReportsFailedSends(t *testing.T) {
	t.Run("send error", func(t *testing.T) {
		f := newRevealerFixture(t, 100)
		f.sender.err = errors.New("execution reverted: L1BlockHashNotFound()")

		err := f.revealer.reveal(context.Background(), 100)
		require.ErrorContains(t, err, "L1BlockHashNotFound")
		assert.Zero(t, f.revealer.revealed)
	})

	t.Run("reverted receipt", func(t *testing.T) {
		f := newRevealerFixture(t, 100)
		f.sender.receipt = &types.Receipt{Status: types.ReceiptStatusFailed}

		err := f.revealer.reveal(context.Background(), 100)
		require.ErrorIs(t, err, errTxReverted)
		assert.Zero(t, f.revealer.revealed)
	})
}

func TestCheckpointRevealerReencodesARealL1Header(t *testing.T) {
	raw, err := os.ReadFile("testdata/mainnet_l1_header_26107693.json")
	require.NoError(t, err)

	var header types.Header

	require.NoError(t, json.Unmarshal(raw, &header))

	var block struct {
		Hash common.Hash `json:"hash"`
	}

	require.NoError(t, json.Unmarshal(raw, &block))

	headerRlp, err := rlp.EncodeToBytes(&header)
	require.NoError(t, err)

	// The revealer sends these bytes, and the Anchor accepts them only if they hash to the block
	// hash L2 recorded. A go-ethereum that drops or misencodes a mainnet header field fails here.
	assert.Equal(t, block.Hash, crypto.Keccak256Hash(headerRlp))
}
