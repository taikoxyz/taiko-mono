package processor

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

// withClock makes the processor's Etna timestamp cache read the returned time, which the test
// moves with the returned function.
func withClock(p *Processor) func(time.Duration) {
	now := time.Unix(1_000_000, 0)
	p.etnaTimestamps.now = func() time.Time { return now }

	return func(d time.Duration) { now = now.Add(d) }
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

func TestEtnaTimestampCachesAnUnsupportedDestination(t *testing.T) {
	tests := []struct {
		name string
		err  error
	}{
		// The L1 Inbox, and an Anchor without the Etna upgrade, revert.
		{name: "revert", err: errors.New("execution reverted")},
		{name: "no contract code", err: bind.ErrNoCode},
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
	anchor := &fakeAnchor{etnaErr: errors.New("dial tcp: connect: connection refused")}

	p := newTestProcessor(false)
	p.destAnchor = anchor
	withClock(p)

	for i := 0; i < 2; i++ {
		_, supported, err := p.etnaTimestamp(context.Background())

		require.ErrorContains(t, err, "connection refused")
		assert.False(t, supported)
	}

	assert.Equal(t, 2, anchor.etnaCalls)
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
