package preconfblocks

import (
	"math/rand"

	"github.com/ethereum-optimism/optimism/op-service/eth"

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
