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

// BatchesProvedEventHandler is responsible for handling the BatchesProved event.
type BatchesProvedEventHandler struct {
	rpc *rpc.Client
}

// NewBatchesProvedEventHandler creates a new BatchesProvedEventHandler instance.
func NewBatchesProvedEventHandler(rpc *rpc.Client) *BatchesProvedEventHandler {
	return &BatchesProvedEventHandler{rpc: rpc}
}

// Handle implements the BatchesProvedHandler interface.
func (h *BatchesProvedEventHandler) Handle(
	ctx context.Context,
	e *shastaBindings.ShastaInboxClientProved,
) error {
	coreState, err := h.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get Shasta core state: %w", err)
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
