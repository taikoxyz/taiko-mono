package preconfblocks

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"
	"gotest.tools/assert"

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

func TestCheckLookaheadHandover_NewLogic(t *testing.T) {
	curr := common.HexToAddress("0xAAA0000000000000000000000000000000000000")
	next := common.HexToAddress("0xBBB0000000000000000000000000000000000000")
	la := &Lookahead{
		CurrOperator: curr,
		NextOperator: next,
		SequencingRanges: []SlotRange{
			{Start: 100, End: 200},
			{Start: 300, End: 400},
		},
	}

	server := &PreconfBlockAPIServer{
		lookahead: la,
		rpc:       &rpc.Client{L1Beacon: &rpc.BeaconClient{SlotsPerEpoch: 32}},
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
		t.Run(tt.name, func(t *testing.T) {
			err := server.checkLookaheadHandover(tt.feeRecipient, tt.globalSlot)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
