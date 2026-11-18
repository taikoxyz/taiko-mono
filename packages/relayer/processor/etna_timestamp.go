package processor

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

// Cache the fork time for a minute so waiting messages do not each poll the destination contracts.
const etnaTimestampCacheTTL = time.Minute

var (
	bridgeSignalServiceSelector = crypto.Keccak256([]byte("signalService()"))[:4]
	beaconRootsFromSelector     = crypto.Keccak256([]byte("beaconRootsFrom()"))[:4]
	errEmptyContractResult      = errors.New("empty contract call result")
)

type etnaTimestampCache struct {
	mu        sync.Mutex
	readAt    time.Time
	timestamp uint64
}

// expire drops the cached read after a legacy proof fails around the fork.
func (c *etnaTimestampCache) expire() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.readAt = time.Time{}
}

// etnaTimestamp reports when the destination SignalService switches to EIP-4788.
// Older contracts without the getter and SignalService instances that return zero
// use checkpoints. Transport failures are retried without caching them.
func (p *Processor) etnaTimestamp(ctx context.Context) (uint64, bool, error) {
	if p.destBridgeAddress == (common.Address{}) {
		return 0, false, nil
	}

	c := &p.etnaTimestamps
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.readAt.IsZero() && p.currentTime().Sub(c.readAt) < etnaTimestampCacheTTL {
		return c.timestamp, c.timestamp != 0, nil
	}

	timestamp, err := p.readEtnaTimestamp(ctx)
	if err != nil && !isUnsupportedCallError(err) {
		return 0, false, err
	}

	c.timestamp = timestamp
	c.readAt = p.currentTime()

	return timestamp, timestamp != 0, nil
}

func (p *Processor) readEtnaTimestamp(ctx context.Context) (uint64, error) {
	// Ask the Bridge which SignalService will verify the proof. This also works
	// for devnets and avoids maintaining a separate destination address.
	word, err := p.readDestinationWord(ctx, p.destBridgeAddress, bridgeSignalServiceSelector)
	if err != nil {
		return 0, fmt.Errorf("Bridge.signalService(): %w", err)
	}

	signalService := common.BytesToAddress(word[:])
	if signalService == (common.Address{}) || word != common.BytesToHash(signalService[:]) {
		return 0, errors.New("Bridge.signalService() returned an invalid address")
	}

	word, err = p.readDestinationWord(ctx, signalService, beaconRootsFromSelector)
	if err != nil {
		return 0, fmt.Errorf("SignalService.beaconRootsFrom(): %w", err)
	}

	timestamp := word.Big()
	if !timestamp.IsUint64() {
		return 0, errors.New("SignalService.beaconRootsFrom() returned an invalid uint64")
	}

	return timestamp.Uint64(), nil
}

func (p *Processor) readDestinationWord(ctx context.Context, address common.Address, data []byte) (common.Hash, error) {
	result, err := p.destEthClient.CallContract(ctx, ethereum.CallMsg{To: &address, Data: data}, nil)
	if err != nil {
		return common.Hash{}, err
	}

	switch len(result) {
	case 0:
		return common.Hash{}, errEmptyContractResult
	case common.HashLength:
		return common.Hash(result), nil
	default:
		return common.Hash{}, fmt.Errorf("expected %d return bytes, got %d", common.HashLength, len(result))
	}
}

// Legacy contracts may revert on an unknown selector or return empty data.
func isUnsupportedCallError(err error) bool {
	return errors.Is(err, errEmptyContractResult) ||
		strings.Contains(strings.ToLower(err.Error()), "execution reverted")
}
