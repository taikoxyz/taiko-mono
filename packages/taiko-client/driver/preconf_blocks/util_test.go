package preconfblocks

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum"
)

func (s *PreconfBlockAPIServerTestSuite) TestBlockToEnvelope() {
	l2Head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	e, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)
	s.Nil(e.EndOfSequencing)
	s.Equal(l2Head.Hash(), e.ExecutionPayload.BlockHash)
	s.Equal(l2Head.Difficulty(), e.HeaderDifficulty)
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
	s.Equal(l2Head.Difficulty(), e.HeaderDifficulty)
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

// TestSetHeadL1OriginUnblocksGuard pins the mechanism handleProposalReorg now relies
// on: after the head L1 origin is rewound to the canonical block ID, the
// checkMessageBlockNumber guard accepts an envelope at origin+1 and rejects one
// at the pinned block ID itself.
func (s *PreconfBlockAPIServerTestSuite) TestSetHeadL1OriginUnblocksGuard() {
	ctx := context.Background()

	l2Head, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)

	pinnedBlockID := l2Head.Number()
	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(ctx, pinnedBlockID)
	s.Nil(err)

	headL1Origin, err := s.RPCClient.L2.HeadL1Origin(ctx)
	s.Nil(err)
	s.Equal(pinnedBlockID.Uint64(), headL1Origin.BlockID.Uint64())

	atGuard, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)
	atGuard.ExecutionPayload.BlockNumber = eth.Uint64Quantity(pinnedBlockID.Uint64())
	_, err = checkMessageBlockNumber(ctx, s.RPCClient, atGuard)
	s.NotNil(err)

	above, err := blockToEnvelope(l2Head, nil, nil, nil)
	s.Nil(err)
	above.ExecutionPayload.BlockNumber = eth.Uint64Quantity(pinnedBlockID.Uint64() + 1)
	_, err = checkMessageBlockNumber(ctx, s.RPCClient, above)
	s.Nil(err)
}
