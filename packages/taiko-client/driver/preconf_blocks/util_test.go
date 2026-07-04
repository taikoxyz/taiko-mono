package preconfblocks

import (
	"context"
)

func (s *PreconfBlockAPIServerTestSuite) TestBlockToEnvelope() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)
	s.Nil(e.EndOfSequencing)
	s.Equal(l2Head.Hash(), e.ExecutionPayload.BlockHash)
}

func (s *PreconfBlockAPIServerTestSuite) TestBlockToEnvelopeMarkers() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	isForcedInclusion := true
	endOfSequencing := true
	signature := [65]byte{1, 2, 3, 4}
	e, err := blockToEnvelope(l2Head, &isForcedInclusion, &endOfSequencing, &signature)
	s.Nil(err)
	s.Equal(isForcedInclusion, *e.IsForcedInclusion)
	s.Equal(endOfSequencing, *e.EndOfSequencing)
	s.Equal(signature, *e.Signature)
	s.Equal(l2Head.Hash(), e.ExecutionPayload.BlockHash)
}

func (s *PreconfBlockAPIServerTestSuite) TestCheckMessageBlockNumber() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)

	_, err = checkMessageBlockNumber(context.Background(), s.RPCClient, e)
	s.NotNil(err)
}
