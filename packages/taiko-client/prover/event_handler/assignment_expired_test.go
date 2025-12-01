package handler

import (
	"context"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func (s *EventHandlerTestSuite) TestAssignmentExpiredEventHandlerHandle() {
	handler := NewAssignmentExpiredEventHandler(
		s.RPCClient,
		s.ShastaStateIndexer,
		make(chan *proofProducer.ProofRequestBody, 1024),
	)
	s.Nil(handler.Handle(context.Background(), s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)))
}
