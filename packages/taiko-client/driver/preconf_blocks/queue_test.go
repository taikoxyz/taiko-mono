package preconfblocks

import (
	"math/rand"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
)

func (s *PreconfBlockAPIServerTestSuite) TestCacheGet() {
	cache := newEnvelopeQueue()
	s.Nil(cache.get(uint64(testutils.RandomPort()), testutils.RandomHash()))
	s.False(cache.hasExact(uint64(testutils.RandomPort()), testutils.RandomHash()))

	payload := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(uint64(testutils.RandomPort())),
			BlockHash:   testutils.RandomHash(),
		},
		HeaderDifficulty: common.Big1,
	}
	cache.put(uint64(payload.Payload.BlockNumber), payload)
	payloadCached := cache.get(uint64(payload.Payload.BlockNumber), payload.Payload.BlockHash)
	s.Equal(payload, payloadCached)
	s.True(cache.hasExact(uint64(payload.Payload.BlockNumber), payload.Payload.BlockHash))
}

func (s *PreconfBlockAPIServerTestSuite) TestCacheGetLongestChildren() {
	cache := newEnvelopeQueue()
	currentPayload := &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(uint64(testutils.RandomPort())),
			BlockHash:   testutils.RandomHash(),
		},
		HeaderDifficulty: common.Big1,
	}

	createFork := func(currentPayload *preconf.Envelope, len int) []*preconf.Envelope {
		payloads := make([]*preconf.Envelope, len)
		parent := currentPayload
		for i := 0; i < len; i++ {
			payload := &preconf.Envelope{
				Payload: &eth.ExecutionPayload{
					BlockNumber: eth.Uint64Quantity(uint64(currentPayload.Payload.BlockNumber) + uint64(i+1)),
					BlockHash:   testutils.RandomHash(),
					ParentHash:  parent.Payload.BlockHash,
				},
				HeaderDifficulty: common.Big1,
			}
			payloads[i] = payload
			parent = payload
			cache.put(uint64(payload.Payload.BlockNumber), payload)
		}
		return payloads
	}

	// Create forks of different lengths
	randomLen := rand.Intn(6) + 5
	fork1 := createFork(currentPayload, randomLen)
	fork2 := createFork(currentPayload, randomLen+1)
	fork3 := createFork(currentPayload, randomLen+3)

	s.Equal(len(fork1), randomLen)
	s.Equal(len(fork2), randomLen+1)
	s.Equal(len(fork3), randomLen+3)
	s.NotEqual(fork1[len(fork1)-1].Payload.BlockHash, fork2[len(fork2)-1].Payload.BlockHash)
	s.NotEqual(fork1[len(fork1)-1].Payload.BlockHash, fork3[len(fork3)-1].Payload.BlockHash)
	s.NotEqual(fork2[len(fork2)-1].Payload.BlockHash, fork3[len(fork3)-1].Payload.BlockHash)
	for i := 0; i < len(fork1)-1; i++ {
		s.Equal(fork1[i].Payload.BlockHash, fork1[i+1].Payload.ParentHash)
		s.Equal(uint64(fork1[i].Payload.BlockNumber+1), uint64(fork1[i+1].Payload.BlockNumber))
	}

	// Search for the longest fork
	longestFork := cache.getChildren(uint64(currentPayload.Payload.BlockNumber), currentPayload.Payload.BlockHash)
	s.Equal(len(longestFork), len(fork3))
	for i := 0; i < len(longestFork)-1; i++ {
		s.Equal(longestFork[i].Payload.BlockNumber, fork3[i].Payload.BlockNumber)
		s.Equal(longestFork[i].Payload.BlockHash, fork3[i].Payload.BlockHash)
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestQueueHighestBlockID() {
	queue := newEnvelopeQueue()

	_, ok := queue.highestBlockID()
	s.False(ok, "an empty queue reports no evidence")

	for _, id := range []uint64{40, 100, 70} {
		queue.put(id, &preconf.Envelope{
			Payload: &eth.ExecutionPayload{
				BlockNumber: eth.Uint64Quantity(id),
				BlockHash:   testutils.RandomHash(),
			},
			HeaderDifficulty: common.Big1,
		})
	}

	// The highest id, not the most recently inserted one: gossip can arrive out of order.
	highest, ok := queue.highestBlockID()
	s.True(ok)
	s.Equal(uint64(100), highest)
}

func (s *PreconfBlockAPIServerTestSuite) TestQueueHighestEnvelopeAbove() {
	var (
		queue   = newEnvelopeQueue()
		backlog = testutils.RandomHash()
		lastPut = testutils.RandomHash()
	)

	put := func(id uint64, hash common.Hash) {
		queue.put(id, &preconf.Envelope{
			Payload: &eth.ExecutionPayload{
				BlockNumber: eth.Uint64Quantity(id),
				BlockHash:   hash,
			},
			HeaderDifficulty: common.Big1,
		})
	}

	s.Nil(queue.highestEnvelopeAbove(0), "an empty queue has no backlog head")

	// The unresolved backlog is cached first; a backfill response for a low block lands after it,
	// which is the ordinary shape while catching up.
	put(200, backlog)
	put(100, lastPut)

	// The head has to sit below both for this to mean anything: query from 100 and the newest
	// entry is not above it either way, so a "first match in newest-first order" implementation
	// would look correct.
	pending := queue.highestEnvelopeAbove(50)
	s.NotNil(pending)
	s.Equal(
		uint64(200),
		uint64(pending.Payload.BlockNumber),
		"retry drives from the backlog head, not the most recently cached envelope",
	)
	s.Equal(backlog, pending.Payload.BlockHash)

	// Once the chain passes the lower entry the backlog head is unchanged.
	pending = queue.highestEnvelopeAbove(100)
	s.NotNil(pending)
	s.Equal(uint64(200), uint64(pending.Payload.BlockNumber))

	s.Nil(queue.highestEnvelopeAbove(200), "nothing above the head means no backlog")
	s.Nil(queue.highestEnvelopeAbove(1000))
}
