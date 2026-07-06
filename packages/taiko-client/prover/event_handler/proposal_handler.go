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

// ProposalEventHandler is responsible for handling proposal events as a prover.
type ProposalEventHandler struct {
	sharedState              *state.SharedState
	proverAddress            common.Address
	rpc                      *rpc.Client
	localProposerAddresses   []common.Address
	assignmentExpiredCh      chan<- metadata.TaikoProposalMetaData
	proofSubmissionCh        chan<- *proofProducer.ProofRequestBody
	backOffRetryInterval     time.Duration
	backOffMaxRetries        uint64
	proveUnassignedProposals bool
}

// NewProposalEventHandlerOps is the options for creating a new ProposalEventHandler.
type NewProposalEventHandlerOps struct {
	SharedState              *state.SharedState
	ProverAddress            common.Address
	RPC                      *rpc.Client
	LocalProposerAddresses   []common.Address
	AssignmentExpiredCh      chan metadata.TaikoProposalMetaData
	ProofSubmissionCh        chan *proofProducer.ProofRequestBody
	BackOffRetryInterval     time.Duration
	BackOffMaxRetries        uint64
	ProveUnassignedProposals bool
}

// NewProposalEventHandler creates a new ProposalEventHandler instance.
func NewProposalEventHandler(opts *NewProposalEventHandlerOps) *ProposalEventHandler {
	return &ProposalEventHandler{
		opts.SharedState,
		opts.ProverAddress,
		opts.RPC,
		opts.LocalProposerAddresses,
		opts.AssignmentExpiredCh,
		opts.ProofSubmissionCh,
		opts.BackOffRetryInterval,
		opts.BackOffMaxRetries,
		opts.ProveUnassignedProposals,
	}
}

// Handle implements the ProposalHandler interface.
func (h *ProposalEventHandler) Handle(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	end eventIterator.EndProposalEventIterFunc,
) error {
	return h.handleProposal(ctx, meta, end)
}

// shouldProve checks whether the current running prover is assigned to prove the proposal.
func (h *ProposalEventHandler) shouldProve(assignedProver common.Address) bool {
	return assignedProver == h.proverAddress ||
		slices.Contains(h.localProposerAddresses, assignedProver)
}
