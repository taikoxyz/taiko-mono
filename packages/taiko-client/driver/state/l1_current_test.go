package state

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-client/internal/testutils"
)

func (s *DriverStateTestSuite) TestGetL1Current() {
	s.NotNil(s.s.GetL1Current())
}

func (s *DriverStateTestSuite) TestSetL1Current() {
	h := &types.Header{ParentHash: testutils.RandomHash()}
	s.s.SetL1Current(h)
	s.Equal(h.Hash(), s.s.GetL1Current().Hash())

	// should warn, but not panic
	s.NotPanics(func() { s.s.SetL1Current(nil) })
}

func (s *DriverStateTestSuite) TestResetL1CurrentEmptyHeight() {
	s.Nil(s.s.ResetL1Current(context.Background(), common.Big0))
}

func (s *DriverStateTestSuite) TestResetL1CurrentEmptyID() {
	s.ErrorContains(s.s.ResetL1Current(context.Background(), common.Big1), "execution reverted")
}

func (s *DriverStateTestSuite) TestResetL1CurrentCtxErr() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	s.ErrorContains(s.s.ResetL1Current(ctx, common.Big0), "context canceled")
}
