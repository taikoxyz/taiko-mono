package preconfblocks

import (
	"context"

	"github.com/ethereum/go-ethereum"
)

func (s *PreconfBlockAPIServerTestSuite) TestBlockToEnvelope() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)
	s.Nil(e.EndOfSequencing)
	s.Equal(l2Head.Hash(), e.ExecutionPayload.BlockHash)
	if l2Head.Difficulty().Sign() > 0 {
		s.Equal(l2Head.Difficulty(), e.HeaderDifficulty)
	} else {
		s.Nil(e.HeaderDifficulty)
	}
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
	if l2Head.Difficulty().Sign() > 0 {
		s.Equal(l2Head.Difficulty(), e.HeaderDifficulty)
	} else {
		s.Nil(e.HeaderDifficulty)
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestCheckMessageBlockNumber() {
	ctx := context.Background()

	l2Head, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)

	headL1Origin, err := s.RPCClient.L2.HeadL1Origin(ctx)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		s.Nil(err)
	}

	_, err = checkMessageBlockNumber(context.Background(), s.RPCClient, e)
	if headL1Origin != nil && uint64(e.ExecutionPayload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
		s.NotNil(err)
		return
	}

	s.Nil(err)
}
