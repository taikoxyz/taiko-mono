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

func (s *ProverEventHandlerTestSuite) TestIsBatchVerified() {
	state2, err := s.RPCClient.PacayaClients.TaikoInbox.GetStats2(nil)
	s.Nil(err)

	batch, err := s.RPCClient.PacayaClients.TaikoInbox.GetBatch(nil, state2.LastVerifiedBatchId)
	s.Nil(err)

	verified, err := isBatchVerified(context.Background(), s.RPCClient, new(big.Int).SetUint64(batch.BatchId))
	s.Nil(err)
	s.True(verified)

	verified, err = isBatchVerified(context.Background(), s.RPCClient, new(big.Int).SetUint64(batch.BatchId+1))
	s.Nil(err)
	s.False(verified)
}

func TestProverEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(ProverEventHandlerTestSuite))
}
