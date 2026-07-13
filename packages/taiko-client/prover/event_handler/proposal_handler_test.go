package handler

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

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

func (s *EventHandlerTestSuite) TestProposalReplayOnlyRedispatchesFailedProposal() {
	proofCh := make(chan *proofProducer.ProofRequestBody, 4)
	shared := state.New()
	first := s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	second := s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	// Seal the second proposal so WaitProposalHeader can resolve its boundary.
	s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)

	handler := NewProposalEventHandler(&NewProposalEventHandlerOps{
		SharedState:          shared,
		ProverAddress:        first.GetProposer(),
		RPC:                  s.RPCClient,
		AssignmentExpiredCh:  make(chan metadata.TaikoProposalMetaData),
		ProofSubmissionCh:    proofCh,
		BackOffRetryInterval: time.Minute,
		BackOffMaxRetries:    5,
	})

	s.NoError(handler.Handle(context.Background(), first, func() {}))
	s.NoError(handler.Handle(context.Background(), second, func() {}))
	firstRequest := <-proofCh
	secondRequest := <-proofCh
	s.Equal(first.GetProposalID(), firstRequest.Meta.GetProposalID())
	s.Equal(second.GetProposalID(), secondRequest.Meta.GetProposalID())

	s.True(shared.RollbackProposalCursor(
		context.Background(),
		first.GetProposalID().Uint64(),
		&types.Header{Number: first.GetRawBlockHeight()},
	))
	s.NoError(handler.Handle(context.Background(), first, func() {}))
	s.NoError(handler.Handle(context.Background(), second, func() {}))
	replayRequest := <-proofCh
	s.Equal(first.GetProposalID(), replayRequest.Meta.GetProposalID())
	s.Never(func() bool { return len(proofCh) != 0 }, 100*time.Millisecond, 10*time.Millisecond)
	s.Equal(second.GetProposalID().Uint64(), shared.GetLastHandledProposalID())
	s.Equal(second.GetRawBlockHeight(), shared.GetL1Current().Number)
	s.Equal(second.GetRawBlockHash(), shared.GetL1Current().Hash())
}

func TestProposalReplayProcessingDecision(t *testing.T) {
	const (
		failedProposalID = uint64(10)
		laterProposalID  = uint64(11)
	)

	shared := state.New()
	handler := NewProposalEventHandler(&NewProposalEventHandlerOps{SharedState: shared})
	shared.MarkProposalProcessing(failedProposalID)
	shared.MarkProposalProcessing(laterProposalID)
	shared.SetLastHandledProposalID(laterProposalID)
	require.True(t, shared.RollbackProposalCursor(
		context.Background(),
		failedProposalID,
		&types.Header{Number: new(big.Int).SetUint64(100)},
	))

	skip, shouldProcess := handler.proposalProcessingDecision(failedProposalID)
	require.False(t, skip)
	require.True(t, shouldProcess)

	shared.SetLastHandledProposalID(failedProposalID)
	shared.MarkProposalProcessing(failedProposalID)
	skip, shouldProcess = handler.proposalProcessingDecision(laterProposalID)
	require.False(t, skip)
	require.False(t, shouldProcess)
}
