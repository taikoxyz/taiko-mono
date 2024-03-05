package state

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-client/internal/utils"
)

type DriverStateTestSuite struct {
	testutils.ClientTestSuite
	s *State
}

func (s *DriverStateTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	state, err := New(context.Background(), s.RPCClient)
	s.Nil(err)
	s.s = state
}

func (s *DriverStateTestSuite) TestVerifyL2Block() {
	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)

	s.Nil(err)
	s.Nil(s.s.VerifyL2Block(context.Background(), head.Number, head.Hash()))
}

func (s *DriverStateTestSuite) TestGetL1Head() {
	l1Head := s.s.GetL1Head()
	s.NotNil(l1Head)
}

func (s *DriverStateTestSuite) TestGetHeadBlockID() {
	s.Equal(uint64(0), s.s.GetHeadBlockID().Uint64())
}

func (s *DriverStateTestSuite) TestClose() {
	s.NotPanics(s.s.Close)
}

func (s *DriverStateTestSuite) TestGetL2Head() {
	testHeight := utils.RandUint64(nil)

	s.s.setL2Head(nil)
	s.s.setL2Head(&types.Header{Number: new(big.Int).SetUint64(testHeight)})
	h := s.s.GetL2Head()
	s.Equal(testHeight, h.Number.Uint64())
}

func (s *DriverStateTestSuite) TestSubL1HeadsFeed() {
	s.NotNil(s.s.SubL1HeadsFeed(make(chan *types.Header)))
}

func (s *DriverStateTestSuite) TestGetSyncedHeaderID() {
	l2Genesis, err := s.RPCClient.L2.BlockByNumber(context.Background(), common.Big0)
	s.Nil(err)

	id, err := s.s.getSyncedHeaderID(context.Background(), s.s.GenesisL1Height.Uint64(), l2Genesis.Hash())
	s.Nil(err)
	s.Zero(id.Uint64())
}

func (s *DriverStateTestSuite) TestNewDriverContextErr() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	state, err := New(ctx, s.RPCClient)
	s.Nil(state)
	s.ErrorContains(err, "context canceled")
}

func (s *DriverStateTestSuite) TestDriverInitContextErr() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := s.s.init(ctx)
	s.ErrorContains(err, "context canceled")
}

func TestDriverStateTestSuite(t *testing.T) {
	suite.Run(t, new(DriverStateTestSuite))
}
