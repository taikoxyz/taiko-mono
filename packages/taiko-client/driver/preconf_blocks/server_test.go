package preconfblocks

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type PreconfBlockAPIServerTestSuite struct {
	testutils.ClientTestSuite
	s *PreconfBlockAPIServer
}

func (s *PreconfBlockAPIServerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	server, err := New(
		"*",
		nil,
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		nil,
		s.RPCClient,
		nil,
	)
	s.Nil(err)
	s.s = server
	go func() {
		s.NotPanics(func() {
			log.Error("Start test preconfirmation block server", "error", s.s.Start(uint64(testutils.RandomPort())))
		})
	}()
}

func (s *PreconfBlockAPIServerTestSuite) TestCheckLookaheadHandover() {
	curr := common.HexToAddress("0xAAA0000000000000000000000000000000000000")
	next := common.HexToAddress("0xBBB0000000000000000000000000000000000000")

	la := &Lookahead{
		CurrOperator: curr,
		NextOperator: next,
		CurrRanges: []SlotRange{
			{Start: 0, End: 32}, // Full epoch 0
		},
		NextRanges: []SlotRange{
			{Start: 32, End: 64}, // Next epoch 1
		},
		UpdatedAt: time.Now().UTC(),
	}

	tests := []struct {
		name       string
		globalSlot uint64
		wantErr    error
	}{
		// Inside CurrRanges
		{name: "curr range early slot", globalSlot: 10, wantErr: nil},
		{name: "curr range at handover slot", globalSlot: 28, wantErr: nil},
		{name: "curr range after handover", globalSlot: 30, wantErr: nil},

		// Inside NextRanges (next epoch)
		{name: "next range next epoch", globalSlot: 33, wantErr: nil},

		// Slot outside all ranges
		{name: "outside all ranges", globalSlot: 70, wantErr: errSlotOutsideSequencingWindow},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.s.lookahead = la
			s.s.rpc.L1Beacon = &rpc.BeaconClient{
				SlotsPerEpoch: 32,
			}

			s.Equal(tt.wantErr, s.s.CheckLookaheadHandover(tt.globalSlot))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestTryPutEnvelopeIntoCache() {
	totalCached := s.s.envelopesCache.totalCached
	isForcedInculsion := true
	peerID := new(peer.ID)

	msg := &eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(new(big.Int).SetBytes(testutils.RandomBytes(32)).Uint64()),
			BlockHash:   common.BytesToHash(testutils.RandomBytes(32)),
		},
		Signature:         &[65]byte{},
		IsForcedInclusion: &isForcedInculsion,
	}

	s.s.tryPutEnvelopeIntoCache(msg, *peerID)
	s.Equal(totalCached+1, s.s.envelopesCache.totalCached)

	cached := s.s.envelopesCache.getLatestEnvelope()
	s.NotNil(cached)
	s.Equal(msg.ExecutionPayload.BlockNumber, cached.Payload.BlockNumber)
	s.Equal(msg.ExecutionPayload.BlockHash, cached.Payload.BlockHash)
	s.Equal(*msg.IsForcedInclusion, cached.IsForcedInclusion)
	s.Equal(msg.Signature, cached.Signature)

	s.s.tryPutEnvelopeIntoCache(msg, *peerID)
	s.Equal(totalCached+1, s.s.envelopesCache.totalCached)
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
