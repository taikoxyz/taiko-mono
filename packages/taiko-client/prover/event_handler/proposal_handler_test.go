package handler

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

func (s *EventHandlerTestSuite) TestProposalHandle() {
	handler := NewProposalEventHandler(&NewProposalEventHandlerOps{
		SharedState:              &state.SharedState{},
		ProverAddress:            common.Address{},
		RPC:                      s.RPCClient,
		AssignmentExpiredCh:      make(chan metadata.TaikoProposalMetaData),
		ProofSubmissionCh:        make(chan *proofProducer.ProofRequestBody),
		BackOffRetryInterval:     1 * time.Minute,
		BackOffMaxRetries:        5,
		ProveUnassignedProposals: true,
	})
	// Propose the proposal to handle, then a following proposal so the handled proposal's
	// last block is sealed by a newer proposal on top of it; WaitProposalHeader only resolves
	// a proposal once its boundary is confirmed this way.
	proposal := s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	s.Nil(handler.Handle(context.Background(), proposal, func() {}))
}
