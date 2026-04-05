package handler

import (
	"context"
	"slices"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

// BatchProposedEventHandler is responsible for handling the BatchProposed event as a prover.
type BatchProposedEventHandler struct {
	sharedState            *state.SharedState
	proverAddress          common.Address
	rpc                    *rpc.Client
	localProposerAddresses []common.Address
	assignmentExpiredCh    chan<- metadata.TaikoProposalMetaData
	proofSubmissionCh      chan<- *proofProducer.ProofRequestBody
	backOffRetryInterval   time.Duration
	backOffMaxRetries      uint64
	proveUnassignedBlocks  bool
}

// NewBatchProposedEventHandlerOps is the options for creating a new BatchProposedEventHandler.
type NewBatchProposedEventHandlerOps struct {
	SharedState            *state.SharedState
	ProverAddress          common.Address
	RPC                    *rpc.Client
	LocalProposerAddresses []common.Address
	AssignmentExpiredCh    chan metadata.TaikoProposalMetaData
	ProofSubmissionCh      chan *proofProducer.ProofRequestBody
	BackOffRetryInterval   time.Duration
	BackOffMaxRetries      uint64
	ProveUnassignedBlocks  bool
}

// NewBatchProposedEventHandler creates a new BatchProposedEventHandler instance.
func NewBatchProposedEventHandler(opts *NewBatchProposedEventHandlerOps) *BatchProposedEventHandler {
	return &BatchProposedEventHandler{
		opts.SharedState,
		opts.ProverAddress,
		opts.RPC,
		opts.LocalProposerAddresses,
		opts.AssignmentExpiredCh,
		opts.ProofSubmissionCh,
		opts.BackOffRetryInterval,
		opts.BackOffMaxRetries,
		opts.ProveUnassignedBlocks,
	}
}

// Handle implements the BatchProposedHandler interface.
func (h *BatchProposedEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndBatchProposedEventIterFunc,
) error {
	return h.handleProposal(ctx, meta, end)
}

// shouldProve checks whether the current running prover is assigned to prove the proposed batch.
func (h *BatchProposedEventHandler) shouldProve(assignedProver common.Address) bool {
	return assignedProver == h.proverAddress ||
		slices.Contains(h.localProposerAddresses, assignedProver)
}
