package handler

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

func (s *EventHandlerTestSuite) TestBlockProposedHandle() {
	handler := NewBlockProposedEventHandler(&NewBlockProposedEventHandlerOps{
		SharedState:           &state.SharedState{},
		ProverAddress:         common.Address{},
		RPC:                   s.RPCClient,
		ProofGenerationCh:     make(chan *proofProducer.ProofResponse),
		AssignmentExpiredCh:   make(chan metadata.TaikoProposalMetaData),
		ProofSubmissionCh:     make(chan *proofProducer.ProofRequestBody),
		ProofContestCh:        make(chan *proofProducer.ContestRequestBody),
		BackOffRetryInterval:  1 * time.Minute,
		BackOffMaxRetrys:      5,
		ContesterMode:         true,
		ProveUnassignedBlocks: true,
	})
	s.Nil(handler.Handle(context.Background(), s.ProposeAndInsertValidBlock(s.proposer, s.blobSyncer), func() {}))
}
