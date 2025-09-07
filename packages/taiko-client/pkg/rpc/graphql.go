package rpc

import (
	"context"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// ShastaProposalInputs represents the inputs needed to propose a Shasta proposal.
type ShastaProposalInputs struct {
	ParentProposals   []shastaBindings.IInboxProposal
	CoreState         shastaBindings.IInboxCoreState
	TransitionRecords []shastaBindings.IInboxTransitionRecord
	Checkpoint        shastaBindings.ICheckpointManagerCheckpoint
}

// GetShastaProposalInputs fetches recent proposals from the GraphQL indexer, will be used to
// propose a Shasta proposal.
func (c *Client) GetShastaProposalInputs(ctx context.Context) (*ShastaProposalInputs, error) {
	if c.ShastaClients.Indexer == nil {
		return nil, errNoGraphQLClient
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var query struct {
		Inputs *ShastaProposalInputs `graphql:"proposed_events(order_by: {block_number: desc}, limit: $limit)"`
	}

	if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &query, map[string]interface{}{"limit": 1}); err != nil {
		return nil, err
	}

	return query.Inputs, nil
}
