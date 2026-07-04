package handler

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// BatchProposedHandler is the interface for handling `TaikoInbox.BatchProposed` events.
type BatchProposedHandler interface {
	Handle(
		ctx context.Context,
		meta metadata.TaikoProposalMetaData,
		end eventIterator.EndBatchProposedEventIterFunc,
	) error
}

// BatchesProvedHandler is the interface for handling `TaikoInbox.BatchesProved` events.
type BatchesProvedHandler interface {
	HandlePacaya(ctx context.Context, e *pacayaBindings.TaikoInboxClientBatchesProved) error
	HandleShasta(ctx context.Context, e *shastaBindings.ShastaInboxClientProved) error
}

// BatchesVerifiedHandler is the interface for handling `TaikoInbox.BatchesVerified` events.
type BatchesVerifiedHandler interface {
	HandlePacaya(ctx context.Context, e *pacayaBindings.TaikoInboxClientBatchesVerified) error
}

// AssignmentExpiredHandler is the interface for handling the proof assignment expiration.
type AssignmentExpiredHandler interface {
	Handle(ctx context.Context, meta metadata.TaikoProposalMetaData) error
}
