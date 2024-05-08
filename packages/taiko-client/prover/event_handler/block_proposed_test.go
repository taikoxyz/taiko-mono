package handler

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-client/bindings"
	proofProducer "github.com/taikoxyz/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-client/prover/shared_state"
)

func (s *EventHandlerTestSuite) TestBlockProposedHandle() {
	opts := &NewBlockProposedEventHandlerOps{
		SharedState:           &state.SharedState{},
		ProverAddress:         common.Address{},
		GenesisHeightL1:       0,
		RPC:                   s.RPCClient,
		ProofGenerationCh:     make(chan *proofProducer.ProofWithHeader),
		AssignmentExpiredCh:   make(chan *bindings.TaikoL1ClientBlockProposed),
		ProofSubmissionCh:     make(chan *proofProducer.ProofRequestBody),
		ProofContestCh:        make(chan *proofProducer.ContestRequestBody),
		BackOffRetryInterval:  1 * time.Minute,
		BackOffMaxRetrys:      5,
		ContesterMode:         true,
		ProveUnassignedBlocks: true,
	}
	handler := NewBlockProposedEventHandler(opts)
	e := s.ProposeAndInsertValidBlock(s.proposer, s.blobSyncer)
	err := handler.Handle(context.Background(), e, func() {})
	s.Nil(err)
}

func (s *EventHandlerTestSuite) TestGetRandomBumpedSubmissionDelay() {
	opts := &NewBlockProposedEventHandlerOps{
		SharedState:           &state.SharedState{},
		ProverAddress:         common.Address{},
		GenesisHeightL1:       0,
		RPC:                   s.RPCClient,
		ProofGenerationCh:     make(chan *proofProducer.ProofWithHeader),
		AssignmentExpiredCh:   make(chan *bindings.TaikoL1ClientBlockProposed),
		ProofSubmissionCh:     make(chan *proofProducer.ProofRequestBody),
		ProofContestCh:        make(chan *proofProducer.ContestRequestBody),
		BackOffRetryInterval:  1 * time.Minute,
		BackOffMaxRetrys:      5,
		ContesterMode:         true,
		ProveUnassignedBlocks: true,
	}
	handler1 := NewBlockProposedEventHandler(opts)

	delay, err := handler1.getRandomBumpedSubmissionDelay(time.Now())
	s.Nil(err)
	s.Zero(delay)

	opts.SubmissionDelay = 1 * time.Hour
	handler2 := NewBlockProposedEventHandler(opts)
	delay, err = handler2.getRandomBumpedSubmissionDelay(time.Now())
	s.Nil(err)
	s.NotZero(delay)
	s.Greater(delay.Seconds(), opts.SubmissionDelay.Seconds())
	s.Less(
		delay.Seconds(),
		opts.SubmissionDelay.Seconds()*(1+(submissionDelayRandomBumpRange/100)),
	)
}
