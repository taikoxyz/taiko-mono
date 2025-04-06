package preconfblocks

import (
	"math/rand"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

func (s *PreconfBlockAPIServerTestSuite) TestCacheGet() {
	cache := newPayloadQueue()
	s.Nil(cache.get(uint64(testutils.RandomPort()), testutils.RandomHash()))
	s.False(cache.has(uint64(testutils.RandomPort()), testutils.RandomHash()))

	payload := &eth.ExecutionPayload{
		BlockNumber: eth.Uint64Quantity(uint64(testutils.RandomPort())),
		BlockHash:   testutils.RandomHash(),
	}
	cache.put(uint64(payload.BlockNumber), payload)
	payloadCached := cache.get(uint64(payload.BlockNumber), payload.BlockHash)
	s.Equal(payload, payloadCached)
	s.True(cache.has(uint64(payload.BlockNumber), payload.BlockHash))
}

func (s *PreconfBlockAPIServerTestSuite) TestCacheGetLongestChildren() {
	cache := newPayloadQueue()
	currentPayload := &eth.ExecutionPayload{
		BlockNumber: eth.Uint64Quantity(uint64(testutils.RandomPort())),
		BlockHash:   testutils.RandomHash(),
	}

	createFork := func(currentPayload *eth.ExecutionPayload, len int) []*eth.ExecutionPayload {
		payloads := make([]*eth.ExecutionPayload, len)
		parent := currentPayload
		for i := 0; i < len; i++ {
			payload := &eth.ExecutionPayload{
				BlockNumber: eth.Uint64Quantity(uint64(currentPayload.BlockNumber) + uint64(i+1)),
				BlockHash:   testutils.RandomHash(),
				ParentHash:  parent.BlockHash,
			}
			payloads[i] = payload
			parent = payload
			cache.put(uint64(payload.BlockNumber), payload)
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
	s.NotEqual(fork1[len(fork1)-1].BlockHash, fork2[len(fork2)-1].BlockHash)
	s.NotEqual(fork1[len(fork1)-1].BlockHash, fork3[len(fork3)-1].BlockHash)
	s.NotEqual(fork2[len(fork2)-1].BlockHash, fork3[len(fork3)-1].BlockHash)
	for i := 0; i < len(fork1)-1; i++ {
		s.Equal(fork1[i].BlockHash, fork1[i+1].ParentHash)
		s.Equal(uint64(fork1[i].BlockNumber+1), uint64(fork1[i+1].BlockNumber))
	}

	// Search for the longest fork
	longestFork := cache.getChildren(uint64(currentPayload.BlockNumber), currentPayload.BlockHash)
	s.Equal(len(longestFork), len(fork3))
	for i := 0; i < len(longestFork)-1; i++ {
		s.Equal(longestFork[i].BlockNumber, fork3[i].BlockNumber)
		s.Equal(longestFork[i].BlockHash, fork3[i].BlockHash)
	}
}
