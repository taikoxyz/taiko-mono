package handler

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

func (s *EventHandlerTestSuite) TestBatchProposedHandle() {
	handler := NewBatchProposedEventHandler(&NewBatchProposedEventHandlerOps{
		SharedState:           &state.SharedState{},
		ProverAddress:         common.Address{},
		RPC:                   s.RPCClient,
		AssignmentExpiredCh:   make(chan metadata.TaikoProposalMetaData),
		ProofSubmissionCh:     make(chan *proofProducer.ProofRequestBody),
		BackOffRetryInterval:  1 * time.Minute,
		BackOffMaxRetries:     5,
		ProveUnassignedBlocks: true,
	})
	s.Nil(handler.Handle(context.Background(), s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer), func() {}))
}
