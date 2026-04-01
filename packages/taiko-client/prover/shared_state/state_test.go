package state

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"
)

type ProverSharedStateTestSuite struct {
	suite.Suite
	state *SharedState
}

func (s *ProverSharedStateTestSuite) SetupTest() {
	s.state = New()
}

func (s *ProverSharedStateTestSuite) TestLastHandledShastaBatchID() {
	newLastHandledBlockID := uint64(1024)
	s.NotEqual(newLastHandledBlockID, s.state.GetLastHandledShastaBatchID())
	s.state.SetLastHandledShastaBatchID(newLastHandledBlockID)
	s.Equal(newLastHandledBlockID, s.state.GetLastHandledShastaBatchID())
}

func (s *ProverSharedStateTestSuite) TestL1Current() {
	newL1Current := &types.Header{Number: common.Big256}
	s.NotEqual(newL1Current, s.state.GetL1Current())
	s.state.SetL1Current(newL1Current)
	s.Equal(newL1Current.Hash(), s.state.GetL1Current().Hash())
}

func TestProverSharedStateTestSuite(t *testing.T) {
	suite.Run(t, new(ProverSharedStateTestSuite))
}
