package processor

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

// testAnchorBase is the L1 anchor of L2 block 0 in etnaFixture; block i anchors to
// testAnchorBase + i.
const testAnchorBase = uint64(1000)

// l2Chain is a destination client serving a fixed list of L2 headers, indexed by number. The head
// is the last header, unless heads is set: then each head read takes the next entry, and the last
// one stays.
type l2Chain struct {
	mock.EthClient
	headers   []*types.Header
	heads     []*types.Header
	headErr   error
	headerErr error
	headReads int
	reads     int
}

func (c *l2Chain) HeaderByNumber(_ context.Context, number *big.Int) (*types.Header, error) {
	c.reads++

	if number != nil {
		if c.headerErr != nil {
			return nil, c.headerErr
		}

		if number.Uint64() >= uint64(len(c.headers)) {
			return nil, ethereum.NotFound
		}

		return c.headers[number.Uint64()], nil
	}

	c.headReads++

	if c.headErr != nil {
		return nil, c.headErr
	}

	if len(c.heads) > 0 {
		head := c.heads[0]

		if len(c.heads) > 1 {
			c.heads = c.heads[1:]
		}

		return head, nil
	}

	return c.headers[len(c.headers)-1], nil
}

// l1Chain is a source client with a fixed head and per-block state roots. blockRoots, when set,
// overrides the roots BlockByNumber returns, as after a reorg between two reads.
type l1Chain struct {
	mock.EthClient
	head       uint64
	headErr    error
	headerErr  error
	roots      map[uint64]common.Hash
	blockRoots map[uint64]common.Hash
}

func (c *l1Chain) BlockNumber(_ context.Context) (uint64, error) {
	return c.head, c.headErr
}

func (c *l1Chain) HeaderByNumber(_ context.Context, number *big.Int) (*types.Header, error) {
	if c.headerErr != nil {
		return nil, c.headerErr
	}

	return &types.Header{Number: number, Root: c.roots[number.Uint64()]}, nil
}

func (c *l1Chain) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	header, err := c.HeaderByNumber(ctx, number)
	if err != nil {
		return nil, err
	}

	if root, ok := c.blockRoots[number.Uint64()]; ok {
		header.Root = root
	}

	return types.NewBlockWithHeader(header), nil
}

// testRoot is the L1 state root of anchor block testAnchorBase + i.
func testRoot(i uint64) common.Hash {
	return common.BigToHash(new(big.Int).SetUint64(0xabc000 + i))
}

// etnaHeader returns an Etna L2 header whose extraData encodes anchor and whose
// parentBeaconBlockRoot is root.
func etnaHeader(number, timestamp, anchor uint64, root common.Hash) *types.Header {
	extra := make([]byte, etnaExtraDataLength)
	extra[0] = 75 // basefeeSharingPctg

	for i := 0; i < 6; i++ {
		extra[12-i] = byte(anchor >> (8 * i))
	}

	return &types.Header{
		Number:           new(big.Int).SetUint64(number),
		Time:             timestamp,
		Extra:            extra,
		ParentBeaconRoot: &root,
	}
}

// etnaFixture returns a processor whose destination is an Etna L2 of ten blocks, 2 s apart from
// etna on, where block i anchors to L1 block testAnchorBase + i with root testRoot(i). Every root
// is recorded by EIP-4788 and matches L1, and the L1 head is two blocks past the newest anchor.
// The processor's clock reads the head's time.
func etnaFixture(etna uint64) (*Processor, *l2Chain, *l1Chain, *fakeAnchor) {
	l2 := &l2Chain{}
	l1 := &l1Chain{head: testAnchorBase + 11, roots: map[uint64]common.Hash{}}
	anchor := &fakeAnchor{etnaTimestamp: etna, roots: map[uint64]common.Hash{}}

	for i := uint64(0); i < 10; i++ {
		header := etnaHeader(i, etna+2*i, testAnchorBase+i, testRoot(i))
		l2.headers = append(l2.headers, header)
		anchor.roots[header.Time] = testRoot(i)
		l1.roots[testAnchorBase+i] = testRoot(i)
	}

	p := newTestProcessor(false)
	p.destEthClient = l2
	p.destAnchor = anchor
	atTime(p, l2.headers[len(l2.headers)-1].Time)

	return p, l2, l1, anchor
}

func TestEtnaAnchorForUsesTheNewestSettledBlock(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)

	// The head (block 9) can still be followed by a block with its timestamp, which would
	// overwrite its EIP-4788 entry, and a node behind the one serving the head may not have
	// blocks 4 to 8 yet, so the proof uses block 3, twelve seconds older than the head.
	anchor, err := p.etnaAnchorFor(context.Background(), l1, l2.headers[9], testEtnaTimestamp, testAnchorBase+2)

	require.NoError(t, err)
	assert.Equal(t, &etnaAnchor{
		l2Timestamp: testEtnaTimestamp + 6,
		l1Block:     testAnchorBase + 3,
		stateRoot:   testRoot(3),
	}, anchor)
}

func TestEtnaAnchorForSkipsBlocksWithTheHeadTimestamp(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)

	// Blocks 3 to 8 share the head's timestamp, so none of their EIP-4788 entries is final.
	for i := 3; i < 9; i++ {
		l2.headers[i].Time = l2.headers[9].Time
	}

	anchor, err := p.etnaAnchorFor(context.Background(), l1, l2.headers[9], testEtnaTimestamp, testAnchorBase+2)

	require.NoError(t, err)
	require.NotNil(t, anchor)
	assert.Equal(t, testEtnaTimestamp+4, anchor.l2Timestamp)
	assert.Equal(t, testAnchorBase+2, anchor.l1Block)
	assert.Equal(t, testRoot(2), anchor.stateRoot)
}

func TestEtnaAnchorForNeedsABlockTwelveSecondsOlderThanTheHead(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)
	head := l2.headers[9]

	// Block 4 is eleven seconds older than the head, block 3 exactly twelve.
	l2.headers[4].Time = head.Time - 11
	require.Equal(t, head.Time-12, l2.headers[3].Time)

	anchor, err := p.etnaAnchorFor(context.Background(), l1, head, testEtnaTimestamp, testAnchorBase)

	require.NoError(t, err)
	require.NotNil(t, anchor)
	assert.Equal(t, head.Time-12, anchor.l2Timestamp)
	assert.Equal(t, testAnchorBase+3, anchor.l1Block)
}

func TestEtnaAnchorForCapsTheSameTimestampLookback(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)

	l2.headers = nil
	for i := uint64(0); i < maxSameTimestampLookback+2; i++ {
		l2.headers = append(l2.headers, etnaHeader(i, testEtnaTimestamp+100, testAnchorBase, testRoot(0)))
	}

	head := l2.headers[len(l2.headers)-1]

	anchor, err := p.etnaAnchorFor(context.Background(), l1, head, testEtnaTimestamp, testAnchorBase)

	require.ErrorIs(t, err, errNoSettledL2Block)
	assert.Nil(t, anchor)
	assert.Equal(t, maxSameTimestampLookback, l2.reads)
}

func TestEtnaAnchorForHasNoSettledBlockBelowGenesis(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)

	anchor, err := p.etnaAnchorFor(context.Background(), l1, l2.headers[0], testEtnaTimestamp, testAnchorBase)

	require.ErrorIs(t, err, errNoSettledL2Block)
	assert.Nil(t, anchor)
}

func TestEtnaAnchorForWaitsOrFails(t *testing.T) {
	otherRoot := common.HexToHash("0xbad")

	tests := []struct {
		name     string
		mutate   func(l2 *l2Chain, l1 *l1Chain, anchor *fakeAnchor)
		etna     uint64
		blockNum uint64
		// wantErr is the sentinel the error wraps; wantErrText is matched when there is none.
		// Neither set means the proof just waits, without an error.
		wantErr     error
		wantErrText string
	}{
		{
			// The first blocks after the fork: block 3 predates it.
			name:     "settled block before the fork",
			mutate:   func(*l2Chain, *l1Chain, *fakeAnchor) {},
			etna:     testEtnaTimestamp + 7,
			blockNum: testAnchorBase,
		},
		{
			name:     "anchor below the message block",
			mutate:   func(*l2Chain, *l1Chain, *fakeAnchor) {},
			blockNum: testAnchorBase + 4,
		},
		{
			name: "extraData without the anchor number",
			mutate: func(l2 *l2Chain, _ *l1Chain, _ *fakeAnchor) {
				l2.headers[3].Extra = l2.headers[3].Extra[:7]
			},
			blockNum: testAnchorBase,
			wantErr:  errMalformedEtnaHeader,
		},
		{
			name: "zero parentBeaconBlockRoot",
			mutate: func(l2 *l2Chain, _ *l1Chain, _ *fakeAnchor) {
				l2.headers[3].ParentBeaconRoot = &common.Hash{}
			},
			blockNum: testAnchorBase,
			wantErr:  errMalformedEtnaHeader,
		},
		{
			name: "no parentBeaconBlockRoot",
			mutate: func(l2 *l2Chain, _ *l1Chain, _ *fakeAnchor) {
				l2.headers[3].ParentBeaconRoot = nil
			},
			blockNum: testAnchorBase,
			wantErr:  errMalformedEtnaHeader,
		},
		{
			name: "anchor older than maxAnchorAge",
			mutate: func(_ *l2Chain, l1 *l1Chain, _ *fakeAnchor) {
				l1.head = testAnchorBase + 3 + maxAnchorAge + 1
			},
			blockNum: testAnchorBase,
			wantErr:  errAnchorTooOld,
		},
		{
			name: "EIP-4788 has no entry",
			mutate: func(_ *l2Chain, _ *l1Chain, anchor *fakeAnchor) {
				delete(anchor.roots, testEtnaTimestamp+6)
			},
			blockNum:    testAnchorBase,
			wantErrText: "getL1StateRoot",
		},
		{
			name: "EIP-4788 holds another root",
			mutate: func(_ *l2Chain, _ *l1Chain, anchor *fakeAnchor) {
				anchor.roots[testEtnaTimestamp+6] = otherRoot
			},
			blockNum: testAnchorBase,
			wantErr:  errOracleRootMismatch,
		},
		{
			name: "L1 anchor block reorged",
			mutate: func(_ *l2Chain, l1 *l1Chain, _ *fakeAnchor) {
				l1.roots[testAnchorBase+3] = otherRoot
			},
			blockNum: testAnchorBase,
			wantErr:  errL1StateRootMismatch,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, l2, l1, anchor := etnaFixture(testEtnaTimestamp)
			tt.mutate(l2, l1, anchor)

			etna := testEtnaTimestamp
			if tt.etna != 0 {
				etna = tt.etna
			}

			got, err := p.etnaAnchorFor(context.Background(), l1, l2.headers[9], etna, tt.blockNum)

			assert.Nil(t, got)

			switch {
			case tt.wantErr != nil:
				require.ErrorIs(t, err, tt.wantErr)
			case tt.wantErrText != "":
				require.ErrorContains(t, err, tt.wantErrText)
				// errOracleRootMismatch names getL1StateRoot too, and is not this error.
				require.NotErrorIs(t, err, errOracleRootMismatch)
			default:
				require.NoError(t, err)
			}
		})
	}
}

func TestEtnaAnchorForNamesTheReadThatFailed(t *testing.T) {
	rpcErr := errors.New("dial tcp: connect: connection refused")

	tests := []struct {
		name     string
		mutate   func(l2 *l2Chain, l1 *l1Chain)
		wantText string
	}{
		{
			name:     "L2 header",
			mutate:   func(l2 *l2Chain, _ *l1Chain) { l2.headerErr = rpcErr },
			wantText: "L2 header 8: ",
		},
		{
			name:     "L1 head",
			mutate:   func(_ *l2Chain, l1 *l1Chain) { l1.headErr = rpcErr },
			wantText: "L1 head: ",
		},
		{
			name:     "L1 header",
			mutate:   func(_ *l2Chain, l1 *l1Chain) { l1.headerErr = rpcErr },
			wantText: "L1 header 1003: ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, l2, l1, _ := etnaFixture(testEtnaTimestamp)
			tt.mutate(l2, l1)

			got, err := p.etnaAnchorFor(context.Background(), l1, l2.headers[9], testEtnaTimestamp, testAnchorBase)

			assert.Nil(t, got)
			require.ErrorIs(t, err, rpcErr)
			require.ErrorContains(t, err, tt.wantText)
		})
	}
}

func TestEtnaAnchorForAcceptsAnAnchorExactlyMaxAnchorAgeOld(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)
	l1.head = testAnchorBase + 3 + maxAnchorAge

	anchor, err := p.etnaAnchorFor(context.Background(), l1, l2.headers[9], testEtnaTimestamp, testAnchorBase)

	require.NoError(t, err)
	require.NotNil(t, anchor)
	assert.Equal(t, testAnchorBase+3, anchor.l1Block)
}

func TestAnchorBlockNumberDecodesBigEndianUint48(t *testing.T) {
	extra := []byte{75, 0, 0, 0, 0, 0, 1, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06}
	assert.Equal(t, uint64(0x010203040506), anchorBlockNumber(extra))

	extra = []byte{0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff}
	assert.Equal(t, uint64(1<<48-1), anchorBlockNumber(extra))
}
