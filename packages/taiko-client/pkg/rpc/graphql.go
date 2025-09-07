package rpc

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// GetProposeInputProposals fetches recent proposals from the GraphQL indexer, will be used to
// propose a Shasta proposal.
func (c *Client) GetProposeInputProposals(ctx context.Context) ([]*shasta.IInboxProposal, error) {
	if c.ShastaClients.Indexer == nil {
		return nil, errNoGraphQLClient
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var q struct {
		ProposedEvents []*shasta.IInboxProposal `graphql:"proposed_events(order_by: {block_number: desc}, limit: $limit)"`
	}

	if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &q, map[string]interface{}{"limit": 1}); err != nil {
		return nil, err
	}

	return q.ProposedEvents, nil
}
