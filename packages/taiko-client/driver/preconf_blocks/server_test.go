package preconfblocks

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
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
	server, err := New("*", nil, 0, common.HexToAddress(os.Getenv("TAIKO_ANCHOR")), nil, s.RPCClient)
	s.Nil(err)
	s.s = server
	go func() {
		s.NotPanics(func() {
			log.Error("Start test preconf block server", "error", s.s.Start(uint64(testutils.RandomPort())))
		})
	}()
}

func (s *PreconfBlockAPIServerTestSuite) TestCheckLookaheadHandover() {
	curr := common.HexToAddress("0xAAA0000000000000000000000000000000000000")
	next := common.HexToAddress("0xBBB0000000000000000000000000000000000000")

	s.s.handoverSlots = 4

	la := &Lookahead{
		CurrOperator: curr,
		NextOperator: next,
		CurrRanges: []SlotRange{
			{Start: 0, End: 28}, // allowed slots 0..27 (handover at 28)
		},
		NextRanges: []SlotRange{
			{Start: 28, End: 32}, // allowed slots 28..31
		},
		UpdatedAt: time.Now().UTC(),
	}

	tests := []struct {
		name         string
		globalSlot   uint64
		feeRecipient common.Address
		wantErr      error
	}{
		{name: "curr in range", globalSlot: 150, feeRecipient: curr, wantErr: nil},
		{name: "next in range", globalSlot: 350, feeRecipient: next, wantErr: nil},
		{name: "curr out range", globalSlot: 250, feeRecipient: curr, wantErr: errInvalidCurrOperator},
		{name: "next out range", globalSlot: 250, feeRecipient: next, wantErr: errInvalidNextOperator},
		{name: "other out range", globalSlot: 250, feeRecipient: common.HexToAddress("0xCCC0000000000000000000000000000000000000"), wantErr: errInvalidNextOperator},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.s.lookahead = la
			s.s.rpc.L1Beacon = &rpc.BeaconClient{
				SlotsPerEpoch: 32,
			}

			s.Equal(tt.wantErr, s.s.checkLookaheadHandover(tt.feeRecipient, tt.globalSlot))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
