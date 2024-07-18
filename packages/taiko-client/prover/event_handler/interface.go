package handler

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// BlockProposedHandler is the interface for handling `TaikoL1.BlockProposed` events.
type BlockProposedHandler interface {
	Handle(ctx context.Context,
		meta metadata.TaikoBlockMetaData,
		end eventIterator.EndBlockProposedEventIterFunc,
	) error
}

// TransitionContestedHandler is the interface for handling `TaikoL1.TransitionContested` events.
type TransitionContestedHandler interface {
	Handle(ctx context.Context, event *bindings.TaikoL1ClientTransitionContested) error
}

// TransitionProvedHandler is the interface for handling `TaikoL1.TransitionProved` events.
type TransitionProvedHandler interface {
	Handle(ctx context.Context, event *bindings.TaikoL1ClientTransitionProved) error
}

// BlockVerifiedHandler is the interface for handling `TaikoL1.BlockVerified` events.
type BlockVerifiedHandler interface {
	Handle(e *bindings.TaikoL1ClientBlockVerified)
}

// AssignmentExpiredHandler is the interface for handling the proof assignment expiration.
type AssignmentExpiredHandler interface {
	Handle(ctx context.Context, meta metadata.TaikoBlockMetaData) error
}
