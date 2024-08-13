package handler

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	v2 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v2"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// BlockProposedHandler is the interface for handling `TaikoL1.BlockProposed` events.
type BlockProposedHandler interface {
	Handle(ctx context.Context,
		meta metadata.TaikoBlockMetaData,
		end eventIterator.EndBlockProposedEventIterFunc,
	) error
}

// TransitionContestedHandler is the interface for handling `TaikoL1.TransitionContestedV2` events.
type TransitionContestedHandler interface {
	Handle(ctx context.Context, event *v2.TaikoL1ClientTransitionContestedV2) error
}

// TransitionProvedHandler is the interface for handling `TaikoL1.TransitionProvedV2` events.
type TransitionProvedHandler interface {
	Handle(ctx context.Context, event *v2.TaikoL1ClientTransitionProvedV2) error
}

// BlockVerifiedHandler is the interface for handling `TaikoL1.BlockVerifiedV2` events.
type BlockVerifiedHandler interface {
	Handle(e *v2.TaikoL1ClientBlockVerifiedV2)
}

// AssignmentExpiredHandler is the interface for handling the proof assignment expiration.
type AssignmentExpiredHandler interface {
	Handle(ctx context.Context, meta metadata.TaikoBlockMetaData) error
}
