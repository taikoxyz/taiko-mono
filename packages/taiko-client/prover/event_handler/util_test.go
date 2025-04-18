package handler

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type ProverEventHandlerTestSuite struct {
	testutils.ClientTestSuite
}

func (s *ProverEventHandlerTestSuite) TestIsBlockVerified() {
	_, slotB, err := s.RPCClient.OntakeClients.TaikoL1.GetStateVariables(nil)
	s.Nil(err)

	verified, err := isBlockVerified(
		context.Background(),
		s.RPCClient,
		new(big.Int).SetUint64(slotB.LastVerifiedBlockId),
	)
	s.Nil(err)
	s.True(verified)

	verified, err = isBlockVerified(
		context.Background(),
		s.RPCClient,
		new(big.Int).SetUint64(slotB.LastVerifiedBlockId+1),
	)
	s.Nil(err)
	s.False(verified)
}

func TestProverEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(ProverEventHandlerTestSuite))
}
