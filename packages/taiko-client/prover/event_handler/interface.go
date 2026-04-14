package handler

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// ProposalHandler is the interface for handling proposal events.
type ProposalHandler interface {
	Handle(
		ctx context.Context,
		meta metadata.TaikoProposalMetaData,
		end eventIterator.EndProposalEventIterFunc,
	) error
}

// ProofsReceivedHandler is the interface for handling proof-received events.
type ProofsReceivedHandler interface {
	Handle(ctx context.Context, e *shastaBindings.ShastaInboxClientProved) error
}

// AssignmentExpiredHandler is the interface for handling the proof assignment expiration.
type AssignmentExpiredHandler interface {
	Handle(ctx context.Context, meta metadata.TaikoProposalMetaData) error
}
