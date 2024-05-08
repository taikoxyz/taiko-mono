package state

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type ProverSharedStateTestSuite struct {
	suite.Suite
	state *SharedState
}

func (s *ProverSharedStateTestSuite) SetupTest() {
	s.state = New()
}

func (s *ProverSharedStateTestSuite) TestLastHandledBlockID() {
	newLastHandledBlockID := uint64(1024)
	s.NotEqual(newLastHandledBlockID, s.state.GetLastHandledBlockID())
	s.state.SetLastHandledBlockID(newLastHandledBlockID)
	s.Equal(newLastHandledBlockID, s.state.GetLastHandledBlockID())
}

func (s *ProverSharedStateTestSuite) TestL1Current() {
	newL1Current := &types.Header{Number: common.Big256}
	s.NotEqual(newL1Current, s.state.GetL1Current())
	s.state.SetL1Current(newL1Current)
	s.Equal(newL1Current.Hash(), s.state.GetL1Current().Hash())
}

func (s *ProverSharedStateTestSuite) TestTiers() {
	s.Empty(s.state.GetTiers())
	s.state.SetTiers([]*rpc.TierProviderTierWithID{{ID: 1}})
	s.Equal(1, len(s.state.GetTiers()))
}

func TestProverSharedStateTestSuite(t *testing.T) {
	suite.Run(t, new(ProverSharedStateTestSuite))
}
