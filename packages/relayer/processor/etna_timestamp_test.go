package processor

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

// testEtnaTimestamp is the Etna fork time of the test chains.
const testEtnaTimestamp = uint64(1_800_000_000)

var (
	testDestBridge    = common.HexToAddress("0x100")
	testSignalService = common.HexToAddress("0x200")
)

type etnaRPC struct {
	mock.EthClient
	etnaTimestamp uint64
	etnaErr       error
	etnaCalls     int
	timestampWord []byte
	beaconWord    []byte
	roots         map[uint64]common.Hash
}

func (c *etnaRPC) CallContract(_ context.Context, msg ethereum.CallMsg, number *big.Int) ([]byte, error) {
	if number != nil || msg.To == nil {
		return nil, errors.New("expected an eth_call at latest to a contract")
	}

	switch *msg.To {
	case testDestBridge:
		if common.Bytes2Hex(msg.Data) != "62d09453" {
			return nil, fmt.Errorf("unexpected Bridge calldata: %x", msg.Data)
		}

		return common.BytesToHash(testSignalService[:]).Bytes(), nil
	case testSignalService:
		c.etnaCalls++

		if common.Bytes2Hex(msg.Data) != "9bce53b5" {
			return nil, fmt.Errorf("unexpected SignalService calldata: %x", msg.Data)
		}

		if c.etnaErr != nil || c.timestampWord != nil {
			return c.timestampWord, c.etnaErr
		}

		var timestamp common.Hash
		binary.BigEndian.PutUint64(timestamp[24:], c.etnaTimestamp)

		return timestamp[:], nil
	case params.BeaconRootsAddress:
		if len(msg.Data) != 32 {
			return nil, fmt.Errorf("unexpected EIP-4788 calldata length: %d", len(msg.Data))
		}

		timestamp := common.Hash(msg.Data).Big()
		if !timestamp.IsUint64() {
			return nil, errors.New("unexpected EIP-4788 timestamp")
		}

		if c.beaconWord != nil {
			return c.beaconWord, nil
		}

		root, ok := c.roots[timestamp.Uint64()]
		if !ok {
			return nil, errors.New("execution reverted")
		}

		return root[:], nil
	default:
		return nil, fmt.Errorf("unexpected contract address: %s", msg.To)
	}
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

func TestEtnaTimestampWithoutADestinationBridgeIsUnsupported(t *testing.T) {
	p := newTestProcessor(false)

	timestamp, supported, err := p.etnaTimestamp(context.Background())

	require.NoError(t, err)
	assert.False(t, supported)
	assert.Zero(t, timestamp)
}

func TestEtnaTimestampIsCachedForAMinute(t *testing.T) {
	destEtna := &etnaRPC{etnaTimestamp: testEtnaTimestamp}

	p := newTestProcessor(false)
	p.destBridgeAddress = testDestBridge
	p.destEthClient = destEtna
	advance := withClock(p)

	for i := 0; i < 3; i++ {
		timestamp, supported, err := p.etnaTimestamp(context.Background())

		require.NoError(t, err)
		assert.True(t, supported)
		assert.Equal(t, testEtnaTimestamp, timestamp)
	}

	assert.Equal(t, 1, destEtna.etnaCalls)

	advance(etnaTimestampCacheTTL - time.Second)

	_, _, err := p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 1, destEtna.etnaCalls)

	advance(time.Second)

	_, _, err = p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 2, destEtna.etnaCalls)
}

func TestEtnaTimestampCachesAnUnsupportedDestination(t *testing.T) {
	tests := []struct {
		name string
		err  error
		word []byte
	}{
		{name: "legacy SignalService reverts", err: errors.New("execution reverted")},
		{name: "Besu revert", err: errors.New("Execution reverted")},
		{name: "no output", word: []byte{}},
		{name: "checkpoint-only SignalService returns zero", word: make([]byte, 32)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			destEtna := &etnaRPC{etnaErr: tt.err, timestampWord: tt.word}

			p := newTestProcessor(false)
			p.destBridgeAddress = testDestBridge
			p.destEthClient = destEtna
			withClock(p)

			for i := 0; i < 2; i++ {
				_, supported, err := p.etnaTimestamp(context.Background())

				require.NoError(t, err)
				assert.False(t, supported)
			}

			assert.Equal(t, 1, destEtna.etnaCalls)
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
			destEtna := &etnaRPC{etnaErr: tt.err}

			p := newTestProcessor(false)
			p.destBridgeAddress = testDestBridge
			p.destEthClient = destEtna
			withClock(p)

			for i := 0; i < 2; i++ {
				_, supported, err := p.etnaTimestamp(context.Background())

				require.ErrorIs(t, err, tt.err)
				assert.False(t, supported)
			}

			assert.Equal(t, 2, destEtna.etnaCalls)
		})
	}
}

func TestEtnaTimestampSeesTheSignalServiceUpgradeAfterTheCacheExpires(t *testing.T) {
	destEtna := &etnaRPC{etnaErr: errors.New("execution reverted")}

	p := newTestProcessor(false)
	p.destBridgeAddress = testDestBridge
	p.destEthClient = destEtna
	advance := withClock(p)

	_, supported, err := p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.False(t, supported)

	// The DAO upgrades the SignalService.
	destEtna.etnaErr = nil
	destEtna.etnaTimestamp = testEtnaTimestamp

	advance(etnaTimestampCacheTTL)

	timestamp, supported, err := p.etnaTimestamp(context.Background())
	require.NoError(t, err)
	assert.True(t, supported)
	assert.Equal(t, testEtnaTimestamp, timestamp)
}
