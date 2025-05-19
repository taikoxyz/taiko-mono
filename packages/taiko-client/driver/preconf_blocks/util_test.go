package preconfblocks

import (
	"context"
)

func (s *PreconfBlockAPIServerTestSuite) TestBlockToEnvelope() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil)
	s.Nil(err)
	s.Nil(e.EndOfSequencing)
	s.Equal(l2Head.Hash(), e.ExecutionPayload.BlockHash)
}

func (s *PreconfBlockAPIServerTestSuite) TestCheckMessageBlockNumber() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil)
	s.Nil(err)

	_, err = checkMessageBlockNumber(context.Background(), s.RPCClient, e)
	s.NotNil(err)
}
