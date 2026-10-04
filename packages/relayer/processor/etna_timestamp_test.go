package processor

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/anchor"
)

// testEtnaTimestamp is the Etna fork time of the test chains.
const testEtnaTimestamp = uint64(1_800_000_000)

// fakeAnchor is a destination Anchor whose Etna timestamp and EIP-4788 roots a test sets.
type fakeAnchor struct {
	etnaTimestamp uint64
	etnaErr       error
	etnaCalls     int
	roots         map[uint64]common.Hash
}

func (a *fakeAnchor) EtnaTimestamp(_ *bind.CallOpts) (uint64, error) {
	a.etnaCalls++

	return a.etnaTimestamp, a.etnaErr
}

func (a *fakeAnchor) GetL1StateRoot(_ *bind.CallOpts, blockID uint64) ([32]byte, error) {
	root, ok := a.roots[blockID]
	if !ok {
		return [32]byte{}, errors.New("execution reverted: L1StateRootNotFound")
	}

	return root, nil
}

// withClock makes the processor's clock read the returned time, which the test moves with the
// returned function.
func withClock(p *Processor) func(time.Duration) {
	now := time.Unix(1_000_000, 0)
	p.now = func() time.Time { return now }

	return func(d time.Duration) { now = now.Add(d) }
}

// atTime stops the processor's clock at Unix time sec.
func atTime(p *Processor, sec uint64) {
	p.now = func() time.Time { return time.Unix(int64(sec), 0) }
}

func TestEtnaTimestampWithoutAnAnchorIsUnsupported(t *testing.T) {
	p := newTestProcessor(false)

	timestamp, supported, err := p.etnaTimestamp(context.Background())

	require.NoError(t, err)
	assert.False(t, supported)
	assert.Zero(t, timestamp)
}

func TestEtnaTimestampIsCachedForAMinute(t *testing.T) {
	anchor := &fakeAnchor{etnaTimestamp: testEtnaTimestamp}

	p := newTestProcessor(false)
	p.destAnchor = anchor
	advance := withClock(p)

	for i := 0; i < 3; i++ {
		timestamp, supported, err := p.etnaTimestamp(context.Background())

		require.NoError(t, err)
		assert.True(t, supported)
		assert.Equal(t, testEtnaTimestamp, timestamp)
	}

	assert.Equal(t, 1, anchor.etnaCalls)

	advance(etnaTimestampCacheTTL - time.Second)

	_, _, err := p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 1, anchor.etnaCalls)

	advance(time.Second)

	_, _, err = p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 2, anchor.etnaCalls)
}

// codeWithoutOutput is a chain where the destination address has code but every call returns no
// data, as a contract whose fallback answers a function it does not have does.
type codeWithoutOutput struct{}

func (codeWithoutOutput) CodeAt(context.Context, common.Address, *big.Int) ([]byte, error) {
	return []byte{0x00}, nil
}

func (codeWithoutOutput) CallContract(context.Context, ethereum.CallMsg, *big.Int) ([]byte, error) {
	return nil, nil
}

func TestEtnaTimestampCachesAnUnsupportedDestination(t *testing.T) {
	// The error the Anchor binding returns when the call succeeds without output.
	caller, err := anchor.NewAnchorCaller(common.Address{}, codeWithoutOutput{})
	require.NoError(t, err)

	_, emptyOutput := caller.EtnaTimestamp(&bind.CallOpts{})
	require.Error(t, emptyOutput)

	tests := []struct {
		name string
		err  error
	}{
		// The L1 Inbox, and an Anchor without the Etna upgrade, revert.
		{name: "revert", err: errors.New("execution reverted")},
		{name: "Besu revert", err: errors.New("Execution reverted")},
		{name: "no contract code", err: bind.ErrNoCode},
		{name: "no output", err: emptyOutput},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			anchor := &fakeAnchor{etnaErr: tt.err}

			p := newTestProcessor(false)
			p.destAnchor = anchor
			withClock(p)

			for i := 0; i < 2; i++ {
				_, supported, err := p.etnaTimestamp(context.Background())

				require.NoError(t, err)
				assert.False(t, supported)
			}

			assert.Equal(t, 1, anchor.etnaCalls)
		})
	}
}

func TestEtnaTimestampDoesNotCacheRPCErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
	}{
		{name: "connection refused", err: errors.New("dial tcp: connect: connection refused")},
		{name: "timeout", err: fmt.Errorf("Post \"http://l2:8545\": %w", context.DeadlineExceeded)},
		{name: "EOF", err: fmt.Errorf("Post \"http://l2:8545\": %w", io.EOF)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			anchor := &fakeAnchor{etnaErr: tt.err}

			p := newTestProcessor(false)
			p.destAnchor = anchor
			withClock(p)

			for i := 0; i < 2; i++ {
				_, supported, err := p.etnaTimestamp(context.Background())

				require.ErrorIs(t, err, tt.err)
				assert.False(t, supported)
			}

			assert.Equal(t, 2, anchor.etnaCalls)
		})
	}
}

func TestEtnaTimestampSeesTheAnchorUpgradeAfterTheCacheExpires(t *testing.T) {
	anchor := &fakeAnchor{etnaErr: errors.New("execution reverted")}

	p := newTestProcessor(false)
	p.destAnchor = anchor
	advance := withClock(p)

	_, supported, err := p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.False(t, supported)

	// The DAO upgrades the Anchor.
	anchor.etnaErr = nil
	anchor.etnaTimestamp = testEtnaTimestamp

	advance(etnaTimestampCacheTTL)

	timestamp, supported, err := p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.True(t, supported)
	assert.Equal(t, testEtnaTimestamp, timestamp)
}
