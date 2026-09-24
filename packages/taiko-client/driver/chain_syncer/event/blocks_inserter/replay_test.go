package blocksinserter

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func TestProposalNotificationStopsWhenConsumerExits(t *testing.T) {
	inserter := &Shasta{latestSeenProposalCh: make(chan *encoding.LastSeenProposal)}
	proposal := &encoding.LastSeenProposal{
		TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(37503)}, 0,
		),
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan struct{})
	go func() {
		inserter.sendLatestSeenProposal(ctx, proposal)
		close(done)
	}()
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("notification sender outlived its consumer context")
	}
}

func TestPreconfirmationImportDoesNotRequireReplayMetricRPC(t *testing.T) {
	// An empty import must not attempt a post-replay canonical lookup. A nil
	// RPC client makes any such dependency fail instead of hiding it in a mock.
	inserter := &Shasta{}
	headers, err := inserter.InsertPreconfBlocksFromEnvelopes(context.Background(), nil, false)
	require.NoError(t, err)
	require.Empty(t, headers)
	inserter.sendLatestSeenProposal(context.Background(), nil)
}
