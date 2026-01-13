package handler

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// BatchesVerifiedEventHandler is responsible for handling the BatchesVerified event.
type BatchesVerifiedEventHandler struct {
	rpc *rpc.Client
}

// NewBatchesVerifiedEventHandler creates a new BatchesVerifiedEventHandler instance.
func NewBatchesVerifiedEventHandler(rpc *rpc.Client) *BatchesVerifiedEventHandler {
	return &BatchesVerifiedEventHandler{rpc: rpc}
}

// HandlePacaya handles the BatchesVerified event.
func (h *BatchesVerifiedEventHandler) HandlePacaya(
	ctx context.Context,
	e *pacayaBindings.TaikoInboxClientBatchesVerified,
) error {
	batch, err := h.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(e.BatchId))
	if err != nil {
		return err
	}
	metrics.ProverLatestVerifiedIDGauge.Set(float64(batch.LastBlockId))

	log.Info(
		"New verified batch",
		"batchID", e.BatchId,
		"lastBlockID", batch.LastBlockId,
		"hash", common.Hash(e.BlockHash),
	)
	return nil
}
