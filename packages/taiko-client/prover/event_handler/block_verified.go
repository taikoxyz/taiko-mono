package handler

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

// BlockVerifiedEventHandler is responsible for handling the BlockVerified event.
type BlockVerifiedEventHandler struct {
	guardianProverAddress common.Address
}

// NewBlockVerifiedEventHandler creates a new BlockVerifiedEventHandler instance.
func NewBlockVerifiedEventHandler(guardianProverAddress common.Address) *BlockVerifiedEventHandler {
	return &BlockVerifiedEventHandler{guardianProverAddress: guardianProverAddress}
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

// Handle handles the BatchVerified event.
func (h *BlockVerifiedEventHandler) HandlePacaya(e *pacayaBindings.TaikoInboxClientBatchesVerified) {
	metrics.ProverLatestVerifiedIDGauge.Set(float64(e.BatchId))

	log.Info(
		"New verified batch",
		"batchID", e.BatchId,
		"hash", common.BytesToHash(e.BlockHash[:]),
	)
}
