package handler

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// BlockVerifiedEventHandler is responsible for handling the BlockVerified event.
type BlockVerifiedEventHandler struct {
	guardianProverAddress common.Address
	rpc                   *rpc.Client
}

// NewBlockVerifiedEventHandler creates a new BlockVerifiedEventHandler instance.
func NewBlockVerifiedEventHandler(rpc *rpc.Client, guardianProverAddress common.Address) *BlockVerifiedEventHandler {
	return &BlockVerifiedEventHandler{rpc: rpc, guardianProverAddress: guardianProverAddress}
}

// Handle handles the BlockVerified event.
func (h *BlockVerifiedEventHandler) Handle(e *ontakeBindings.TaikoL1ClientBlockVerifiedV2) {
	metrics.ProverLatestVerifiedIDGauge.Set(float64(e.BlockId.Uint64()))

	log.Info(
		"New verified block",
		"blockID", e.BlockId,
		"hash", common.BytesToHash(e.BlockHash[:]),
		"prover", e.Prover,
	)
}

// HandlePacaya handles the BatchesVerified event.
func (h *BlockVerifiedEventHandler) HandlePacaya(
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
		"hash", common.BytesToHash(e.BlockHash[:]),
	)
	return nil
}
