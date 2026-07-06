package handler

import (
	"context"
	"fmt"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/log"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ProofsReceivedEventHandler is responsible for handling proof-received events.
type ProofsReceivedEventHandler struct {
	rpc *rpc.Client
}

// NewProofsReceivedEventHandler creates a new ProofsReceivedEventHandler instance.
func NewProofsReceivedEventHandler(rpc *rpc.Client) *ProofsReceivedEventHandler {
	return &ProofsReceivedEventHandler{rpc: rpc}
}

// Handle implements the ProofsReceivedHandler interface.
func (h *ProofsReceivedEventHandler) Handle(
	ctx context.Context,
	e *shastaBindings.ShastaInboxClientProved,
) error {
	coreState, err := h.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get core state: %w", err)
	}

	header, err := h.rpc.L2.HeaderByHash(ctx, coreState.LastFinalizedBlockHash)
	if err != nil {
		return fmt.Errorf("failed to get L2 header by hash: %w", err)
	}
	metrics.ProverLatestVerifiedIDGauge.Set(float64(header.Number.Uint64()))

	log.Info(
		"New valid proposal proofs received",
		"firstProposalID", e.FirstNewProposalId,
		"lastProposalID", e.LastProposalId,
		"actualProver", e.ActualProver,
		"checkpointBlockHash", coreState.LastFinalizedBlockHash,
	)

	return nil
}
