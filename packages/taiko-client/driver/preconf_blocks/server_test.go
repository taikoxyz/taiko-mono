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
	server, err := New("*",
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
		name         string
		globalSlot   uint64
		feeRecipient common.Address
		wantErr      error
	}{
		// Inside CurrRanges, before handover point
		{name: "curr allowed early slot", globalSlot: 10, feeRecipient: curr, wantErr: nil},

		// Inside CurrRanges, at handover threshold
		{name: "next allowed at handover slot", globalSlot: 28, feeRecipient: next, wantErr: nil},

		// Inside CurrRanges, after threshold
		{name: "next allowed after handover", globalSlot: 30, feeRecipient: next, wantErr: nil},

		// Inside NextRanges (next epoch)
		{name: "next allowed next epoch", globalSlot: 33, feeRecipient: next, wantErr: nil},

		// Slot outside all ranges (invalid)
		{
			name:         "random address wrong",
			globalSlot:   70,
			feeRecipient: common.HexToAddress("0xCCC0000000000000000000000000000000000000"),
			wantErr:      errInvalidNextOperator,
		},
		{name: "curr wrong outside", globalSlot: 70, feeRecipient: curr, wantErr: errInvalidCurrOperator},
		{name: "next wrong outside", globalSlot: 70, feeRecipient: next, wantErr: errInvalidNextOperator},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.s.lookahead = la
			s.s.rpc.L1Beacon = &rpc.BeaconClient{
				SlotsPerEpoch: 32,
			}

			s.Equal(tt.wantErr, s.s.CheckLookaheadHandover(tt.feeRecipient, tt.globalSlot))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
