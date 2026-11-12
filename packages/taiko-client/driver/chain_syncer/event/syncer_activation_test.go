package event

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Removing the proposal-zero skip must touch a nil runtime dependency and fail this unit test.
func TestProcessProposalSkipsActivationProposal(t *testing.T) {
	meta := metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{
		Id: new(big.Int),
	}, 0)
	syncer := &Syncer{lastInsertedProposalID: big.NewInt(99)}
	// RPC, state, progress tracker, fetcher and inserter deliberately remain nil:
	// activation must return before any of those live dependencies are used.
	require.NoError(t, syncer.processProposal(context.Background(), meta, func() {
		t.Fatal("activation proposal must not end the proposal iterator")
	}))
	require.Zero(t, syncer.lastInsertedProposalID.Sign())
}
