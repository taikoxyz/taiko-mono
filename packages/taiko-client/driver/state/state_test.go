package state

import (
	"context"
	"crypto/rand"
	"math"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type DriverStateTestSuite struct {
	testutils.ClientTestSuite
	ctx    context.Context
	cancel context.CancelFunc
	s      *State
}

func (s *DriverStateTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	s.ctx, s.cancel = context.WithCancel(context.Background())
	state, err := New(s.ctx, s.RPCClient)
	s.Nil(err)
	s.s = state
}

func (s *DriverStateTestSuite) TearDownTest() {
	defer s.ClientTestSuite.TearDownTest()
	if s.ctx.Err() == nil {
		s.cancel()
	}
}

func (s *DriverStateTestSuite) TestGetL1Head() {
	l1Head := s.s.GetL1Head()
	s.NotNil(l1Head)
}

func (s *DriverStateTestSuite) TestClose() {
	s.cancel()
	s.NotPanics(s.s.Close)
}

func (s *DriverStateTestSuite) TestGetL2Head() {
	testHeight := RandUint64(nil)

	s.s.setL2Head(nil)
	s.s.setL2Head(&types.Header{Number: new(big.Int).SetUint64(testHeight)})
	h := s.s.GetL2Head()
	s.Equal(testHeight, h.Number.Uint64())
}

func (s *DriverStateTestSuite) TestSubL1HeadsFeed() {
	s.NotNil(s.s.SubL1HeadsFeed(make(chan *types.Header)))
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

// RandUint64 returns a random uint64 number.
func RandUint64(max *big.Int) uint64 {
	if max == nil {
		max = new(big.Int)
		max.SetUint64(math.MaxUint64)
	}
	num, _ := rand.Int(rand.Reader, max)

	return num.Uint64()
}
