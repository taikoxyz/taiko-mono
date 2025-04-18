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
	l := &Lookahead{
		CurrOperator: common.HexToAddress("0x1234567890123456789012345678901234567890"),
		NextOperator: common.HexToAddress("0x0987654321098765432109876543210987654321"),
	}

	sameOperatorLookahead := &Lookahead{
		CurrOperator: common.HexToAddress("0x1234567890123456789012345678901234567890"),
		NextOperator: common.HexToAddress("0x1234567890123456789012345678901234567890"),
	}

	tests := []struct {
		name          string
		slotsPerEpoch uint64
		handoverSlots uint64
		lookahead     *Lookahead
		currentSlot   uint64
		feeRecipient  common.Address
		wantErr       error
	}{
		{"currOperator zero handover skip slots", 32, 0, l, 27, l.CurrOperator, nil},
		{"nextOperator zero handover skip slots", 32, 0, l, 1, l.NextOperator, errInvalidCurrOperator},
		{"currOperator on edge", 32, 4, l, 27, l.CurrOperator, nil},
		{"currOperator too late", 32, 4, l, 28, l.CurrOperator, errInvalidNextOperator},
		{"nextOperator on edge", 32, 4, l, 28, l.NextOperator, nil},
		{"nextOperator too early", 32, 4, l, 27, l.NextOperator, errInvalidCurrOperator},
		{"currOperator and nextOperator the same", 32, 4, sameOperatorLookahead, 27, l.NextOperator, nil},
		{"currOperator on edge small handover slots", 32, 1, l, 30, l.CurrOperator, nil},
		{"currOperator too late small handover slots", 32, 1, l, 31, l.CurrOperator, errInvalidNextOperator},
		{"nextOperator on edge small handover slots", 32, 1, l, 31, l.NextOperator, nil},
		{"nextOperator too early small handover slots", 32, 1, l, 30, l.NextOperator, errInvalidCurrOperator},
		{
			"currOperator and nextOperator the same small handover slots",
			32,
			4,
			sameOperatorLookahead,
			27,
			l.NextOperator,
			nil,
		},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.s.handoverSlots = tt.handoverSlots
			s.s.lookahead = tt.lookahead
			s.s.rpc.L1Beacon = &rpc.BeaconClient{
				SlotsPerEpoch:  tt.slotsPerEpoch,
				SecondsPerSlot: uint64(time.Now().UTC().Unix()) / tt.currentSlot,
			}
			s.Equal(s.s.checkLookaheadHandover(tt.feeRecipient), tt.wantErr)
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
