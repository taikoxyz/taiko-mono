package prover

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

func TestProposalRetryExhaustionRollsBackCursor(t *testing.T) {
	ctx := context.Background()
	p := &Prover{
		ctx:         ctx,
		cfg:         &Config{},
		sharedState: state.New(),
	}
	p.sharedState.SetLastHandledProposalID(42)
	p.sharedState.SetL1Current(&types.Header{Number: big.NewInt(100)})
	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:  big.NewInt(21),
			Raw: types.Log{BlockNumber: 88},
		},
		0,
	)

	p.withRetry(
		func() error { return errors.New("RPC unavailable") },
		p.rollbackProposalCursorOnRetryExhaustion(meta),
	)
	p.wg.Wait()

	require.Equal(t, uint64(20), p.sharedState.GetLastHandledProposalID())
	require.Equal(t, uint64(88), p.sharedState.GetL1Current().Number.Uint64())
}

func TestProposalRetryExhaustionDoesNotRollBackAfterCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	p := &Prover{
		ctx:         ctx,
		cfg:         &Config{},
		sharedState: state.New(),
	}
	p.sharedState.SetLastHandledProposalID(42)
	p.sharedState.SetL1Current(&types.Header{Number: big.NewInt(100)})
	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:  big.NewInt(21),
			Raw: types.Log{BlockNumber: 88},
		},
		0,
	)
	cancel()

	p.withRetry(
		func() error { return errors.New("RPC unavailable") },
		p.rollbackProposalCursorOnRetryExhaustion(meta),
	)
	p.wg.Wait()

	require.Equal(t, uint64(42), p.sharedState.GetLastHandledProposalID())
	require.Equal(t, uint64(100), p.sharedState.GetL1Current().Number.Uint64())
}

func TestProposalRetryExhaustionRejectsInvalidMetadata(t *testing.T) {
	var typedNil *metadata.TaikoProposalMetadataShasta
	tests := []struct {
		name string
		meta metadata.TaikoProposalMetaData
	}{
		{name: "nil", meta: nil},
		{name: "typed nil", meta: typedNil},
		{
			name: "zero proposal ID",
			meta: metadata.NewTaikoProposalMetadataShasta(
				&shastaBindings.ShastaInboxClientProposed{
					Id:  new(big.Int),
					Raw: types.Log{BlockNumber: 88},
				},
				0,
			),
		},
		{
			name: "zero L1 height",
			meta: metadata.NewTaikoProposalMetadataShasta(
				&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(21)},
				0,
			),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := &Prover{
				ctx:         context.Background(),
				sharedState: state.New(),
			}
			p.sharedState.SetLastHandledProposalID(42)
			p.sharedState.SetL1Current(&types.Header{Number: big.NewInt(100)})

			require.Error(t, p.rollbackProposalCursorOnRetryExhaustion(tt.meta)())
			require.Equal(t, uint64(42), p.sharedState.GetLastHandledProposalID())
			require.Equal(t, uint64(100), p.sharedState.GetL1Current().Number.Uint64())
		})
	}
}
