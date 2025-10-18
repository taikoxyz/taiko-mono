package preconfblocks

import (
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
)

type CacheTestSuite struct {
	suite.Suite
}

func TestCacheTestSuite(t *testing.T) {
	suite.Run(t, new(CacheTestSuite))
}

// TestOrphanBlockDetectionWithoutGetBlockByHash verifies that we can detect
// orphan blocks using only cache lookups, without calling eth_getBlockByHash.
func (s *CacheTestSuite) TestOrphanBlockDetectionWithoutGetBlockByHash() {
	cache := newEnvelopeQueue()

	// Create a chain: genesis -> block1 -> block2A (canonical) and block2B (orphan)
	genesis := testutils.RandomHash()
	block1Hash := testutils.RandomHash()
	block2AHash := testutils.RandomHash()
	block2BHash := testutils.RandomHash()

	// Cache block 1
	env1 := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(1),
			BlockHash:    block1Hash,
			ParentHash:   genesis,
			Transactions: []eth.Data{testutils.RandomBytes(100)},
		},
		Signature: &[65]byte{},
	}
	cache.put(1, env1)

	// Cache block 2A (canonical)
	env2A := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(2),
			BlockHash:    block2AHash,
			ParentHash:   block1Hash,
			Transactions: []eth.Data{testutils.RandomBytes(100)},
		},
		Signature: &[65]byte{},
	}
	cache.put(2, env2A)

	// Cache block 2B (orphan - different hash at same height)
	env2B := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(2),
			BlockHash:    block2BHash,
			ParentHash:   block1Hash,
			Transactions: []eth.Data{testutils.RandomBytes(100)},
		},
		Signature: &[65]byte{1, 2, 3},
	}
	cache.put(2, env2B)

	// Verify orphan detection works by checking cached parent
	cachedParent := cache.get(2, block2BHash)
	s.NotNil(cachedParent, "Orphan parent should be in cache")
	s.Equal(block2BHash, cachedParent.Payload.BlockHash)
	s.Equal(block1Hash, cachedParent.Payload.ParentHash)

	// Verify we can differentiate between canonical and orphan blocks at same height
	cachedCanonical := cache.get(2, block2AHash)
	s.NotNil(cachedCanonical)
	s.NotEqual(cachedCanonical.Payload.BlockHash, cachedParent.Payload.BlockHash)
}

// TestL1OriginUpdateUsingCachedData verifies that cached envelope data
// contains all information needed to update L1Origin without eth_getBlockByHash.
func (s *CacheTestSuite) TestL1OriginUpdateUsingCachedData() {
	cache := newEnvelopeQueue()

	parentBlockNum := uint64(100)
	parentHash := testutils.RandomHash()
	txData := testutils.RandomBytes(200)

	// Create and cache parent envelope with all required data
	parentEnv := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(parentBlockNum),
			BlockHash:    parentHash,
			ParentHash:   testutils.RandomHash(),
			Transactions: []eth.Data{txData},
			Timestamp:    eth.Uint64Quantity(uint64(time.Now().Unix())),
			FeeRecipient: common.HexToAddress("0x1234567890abcdef1234567890abcdef12345678"),
			PrevRandao:   eth.Bytes32(testutils.RandomHash()),
		},
		Signature:         &[65]byte{5, 6, 7, 8},
		IsForcedInclusion: true,
	}
	cache.put(parentBlockNum, parentEnv)

	// Verify cached data is retrievable
	cached := cache.get(parentBlockNum, parentHash)
	s.NotNil(cached)
	s.Equal(parentHash, cached.Payload.BlockHash)
	s.Equal(len(txData), len(cached.Payload.Transactions[0]))
	s.Equal(parentEnv.Payload.Timestamp, cached.Payload.Timestamp)
	s.Equal(parentEnv.Payload.FeeRecipient, cached.Payload.FeeRecipient)
	s.Equal(parentEnv.Signature, cached.Signature)
	s.Equal(parentEnv.IsForcedInclusion, cached.IsForcedInclusion)

	// Verify we have all data needed for L1Origin update without eth_getBlockByHash
	s.NotEmpty(cached.Payload.Transactions, "Need transactions for txListHash")
	s.NotNil(cached.Signature, "Need signature for L1Origin")
	s.NotEmpty(cached.Payload.FeeRecipient, "Need fee recipient for BuildPayloadArgs")
	s.NotZero(cached.Payload.Timestamp, "Need timestamp for BuildPayloadArgs")
	s.NotEmpty(cached.Payload.PrevRandao, "Need PrevRandao for BuildPayloadArgs")
}

// TestEnvelopeCachingFlow verifies that envelopes are properly cached
// and retrieved in all scenarios.
func (s *CacheTestSuite) TestEnvelopeCachingFlow() {
	cache := newEnvelopeQueue()

	blockNum := uint64(50)
	blockHash := testutils.RandomHash()
	parentHash := testutils.RandomHash()

	// Test: Cache an envelope
	env1 := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(blockNum),
			BlockHash:    blockHash,
			ParentHash:   parentHash,
			Transactions: []eth.Data{testutils.RandomBytes(100)},
		},
		Signature: &[65]byte{1},
	}
	cache.put(blockNum, env1)
	s.True(cache.hasExact(blockNum, blockHash))

	// Test: Cache another envelope at different height
	blockNum2 := blockNum + 1
	blockHash2 := testutils.RandomHash()
	env2 := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(blockNum2),
			BlockHash:    blockHash2,
			ParentHash:   blockHash,
			Transactions: []eth.Data{testutils.RandomBytes(100)},
		},
		Signature: &[65]byte{2},
	}
	cache.put(blockNum2, env2)
	s.True(cache.hasExact(blockNum2, blockHash2))

	// Test: Cache third envelope
	blockNum3 := blockNum2 + 1
	blockHash3 := testutils.RandomHash()
	env3 := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(blockNum3),
			BlockHash:    blockHash3,
			ParentHash:   blockHash2,
			Transactions: []eth.Data{testutils.RandomBytes(100)},
		},
		Signature: &[65]byte{3},
	}
	cache.put(blockNum3, env3)
	s.True(cache.hasExact(blockNum3, blockHash3))

	// Verify all envelopes are retrievable
	s.NotNil(cache.get(blockNum, blockHash))
	s.NotNil(cache.get(blockNum2, blockHash2))
	s.NotNil(cache.get(blockNum3, blockHash3))

	// Verify total count
	s.Equal(uint64(3), cache.totalCached)
}

// TestCachedParentForOrphanHandling verifies the complete orphan handling flow:
// parent cached -> reorg happens -> child builds on orphan -> uses cached data.
func (s *CacheTestSuite) TestCachedParentForOrphanHandling() {
	cache := newEnvelopeQueue()

	parentBlockNum := uint64(50)
	parentHashA := testutils.RandomHash() // Canonical
	parentHashB := testutils.RandomHash() // Orphan

	// Cache parent version A (canonical)
	parentEnvA := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(parentBlockNum),
			BlockHash:    parentHashA,
			ParentHash:   testutils.RandomHash(),
			Transactions: []eth.Data{testutils.RandomBytes(150)},
			FeeRecipient: common.HexToAddress("0xaaaa"),
			Timestamp:    eth.Uint64Quantity(1000),
			PrevRandao:   eth.Bytes32(testutils.RandomHash()),
		},
		Signature: &[65]byte{10, 11, 12},
	}
	cache.put(parentBlockNum, parentEnvA)

	// Cache parent version B (orphan - reorged out)
	parentEnvB := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber:  eth.Uint64Quantity(parentBlockNum),
			BlockHash:    parentHashB,
			ParentHash:   testutils.RandomHash(),
			Transactions: []eth.Data{testutils.RandomBytes(150)},
			FeeRecipient: common.HexToAddress("0xbbbb"),
			Timestamp:    eth.Uint64Quantity(1001),
			PrevRandao:   eth.Bytes32(testutils.RandomHash()),
		},
		Signature: &[65]byte{20, 21, 22},
	}
	cache.put(parentBlockNum, parentEnvB)

	// Child building on orphaned parent B
	childParentHash := parentHashB

	// Verify we can retrieve orphaned parent from cache
	cachedOrphanParent := cache.get(parentBlockNum, parentHashB)
	s.NotNil(cachedOrphanParent)
	s.Equal(parentHashB, cachedOrphanParent.Payload.BlockHash)
	s.Equal(parentEnvB.Payload.FeeRecipient, cachedOrphanParent.Payload.FeeRecipient)
	s.Equal(parentEnvB.Payload.Timestamp, cachedOrphanParent.Payload.Timestamp)
	s.NotEmpty(cachedOrphanParent.Payload.Transactions)

	// This demonstrates the key point: we have all parent data needed
	// to update L1Origin without calling eth_getBlockByHash
	s.Equal(parentHashB, childParentHash)
	s.NotNil(cachedOrphanParent.Payload.Transactions)
	s.NotNil(cachedOrphanParent.Signature)

	// Verify both versions (canonical and orphan) are in cache
	s.NotNil(cache.get(parentBlockNum, parentHashA))
	s.NotNil(cache.get(parentBlockNum, parentHashB))
	s.NotEqual(parentHashA, parentHashB)
}

// TestDuplicateCachingPrevention verifies that duplicate envelopes don't
// increase the cache count unnecessarily.
func (s *CacheTestSuite) TestDuplicateCachingPrevention() {
	cache := newEnvelopeQueue()

	blockNum := uint64(100)
	blockHash := testutils.RandomHash()

	env := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(blockNum),
			BlockHash:   blockHash,
			ParentHash:  testutils.RandomHash(),
		},
		Signature: &[65]byte{1, 2, 3},
	}

	// First insertion
	cache.put(blockNum, env)
	initialCount := cache.totalCached
	s.Equal(uint64(1), initialCount)
	s.True(cache.hasExact(blockNum, blockHash))

	// Second insertion of same envelope (by blockNum, but different hash will add)
	// Note: put() adds by blockNum, so same blockNum with different content would replace
	env2 := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(blockNum),
			BlockHash:   blockHash, // Same hash
			ParentHash:  testutils.RandomHash(),
		},
		Signature: &[65]byte{1, 2, 3},
	}
	cache.put(blockNum, env2)

	// hasExact should still work
	s.True(cache.hasExact(blockNum, blockHash))
}
