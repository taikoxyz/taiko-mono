package blocksinserter

import (
	"context"
	"math/big"
	"testing"
	"time"

	dto "github.com/prometheus/client_model/go"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

func TestProposalNotificationDoesNotBlockWithoutConsumer(t *testing.T) {
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
	select {
	case <-done:
	case <-time.After(time.Second):
		cancel()
		<-done
		t.Fatal("notification blocked without a consumer")
	}
}

func TestFullProposalQueueRetainsNewestCompletionWithoutBlocking(t *testing.T) {
	inserter := &Shasta{latestSeenProposalCh: make(chan *encoding.LastSeenProposal, 1)}
	older := &encoding.LastSeenProposal{
		TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(37504)}, 0,
		),
	}
	latest := &encoding.LastSeenProposal{
		TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(37503)}, 0,
		),
	}
	inserter.latestSeenProposalCh <- older
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan struct{})
	go func() {
		inserter.mutex.Lock()
		defer inserter.mutex.Unlock()
		inserter.sendLatestSeenProposal(ctx, latest)
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		cancel()
		<-done
		t.Fatal("full notification queue blocked block insertion")
	}
	require.Same(t, latest, <-inserter.latestSeenProposalCh)
}

func TestProposalNotificationsKeepDerivationOrder(t *testing.T) {
	inserter := &Shasta{latestSeenProposalCh: make(chan *encoding.LastSeenProposal, 3)}
	proposals := make([]*encoding.LastSeenProposal, 0, 3)
	for n, id := range []int64{37504, 37503, 37503} {
		proposal := &encoding.LastSeenProposal{
			TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
				&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(id)}, 0,
			),
			LastBlockID: uint64(11802684 - n),
		}
		proposals = append(proposals, proposal)
		inserter.mutex.Lock()
		inserter.sendLatestSeenProposal(context.Background(), proposal)
		inserter.mutex.Unlock()
	}
	for _, proposal := range proposals {
		require.Same(t, proposal, <-inserter.latestSeenProposalCh)
	}
}

func TestProposalReplayCounterSurvivesQueueCoalescing(t *testing.T) {
	inserter := &Shasta{latestSeenProposalCh: make(chan *encoding.LastSeenProposal, 1)}
	var before, after dto.Metric
	require.NoError(t, metrics.DriverReorgsByProposalCounter.Write(&before))
	for n := 0; n < 2; n++ {
		inserter.sendLatestSeenProposal(context.Background(), &encoding.LastSeenProposal{PreconfChainReorged: true})
	}
	require.Len(t, inserter.latestSeenProposalCh, 1)
	require.NoError(t, metrics.DriverReorgsByProposalCounter.Write(&after))
	require.Equal(t, before.GetCounter().GetValue()+2, after.GetCounter().GetValue())
}

func TestProposalNotificationsDisabled(t *testing.T) {
	inserter := &Shasta{}
	inserter.sendLatestSeenProposal(context.Background(), nil)
}
