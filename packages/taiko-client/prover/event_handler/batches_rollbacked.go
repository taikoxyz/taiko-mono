package handler

import (
	"context"

	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/types"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

// BatchesRollbackedEventHandler is responsible for handling the BatchesRollbacked event.
type BatchesRollbackedEventHandler struct {
	sharedState *state.SharedState
}

// NewBatchesRollbackedEventHandlerOps is the options for creating a new BatchesRollbackedEventHandler.
type NewBatchesRollbackedEventHandlerOps struct {
	SharedState *state.SharedState
}

// NewBatchesRollbackedEventHandler creates a new BatchesRollbackedEventHandler instance.
func NewBatchesRollbackedEventHandler(opts *NewBatchesRollbackedEventHandlerOps) *BatchesRollbackedEventHandler {
	return &BatchesRollbackedEventHandler{
		sharedState: opts.SharedState,
	}
}

// Handle implements the BatchesRollbackedHandler interface.
func (h *BatchesRollbackedEventHandler) Handle(
	ctx context.Context,
	e *pacayaBindings.TaikoInboxClientBatchesRollbacked,
	end eventIterator.EndBatchesRollbackedEventIterFunc,
) error {
	log.Info(
		"New BatchesRollbacked event",
		"startBatchID", e.StartId,
		"endBatchID", e.EndId,
		"l1BlockHeight", e.Raw.BlockNumber,
		"totalBatchesRollBacked", e.EndId-e.StartId+1,
	)

	// Add the new batches rollbacked range to the shared state.
	h.sharedState.AddBatchesRollbackedRange(
		types.BatchesRollbacked{
			StartBatchID: e.StartId,
			EndBatchID:   e.EndId,
		},
	)

	return nil
}
