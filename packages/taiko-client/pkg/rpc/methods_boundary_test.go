package rpc

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

func TestEvaluateProposalSeal(t *testing.T) {
	proposalID := big.NewInt(5)

	newerExtra, err := encoding.EncodeShastaExtraData(0, big.NewInt(6)) // newer proposal
	require.NoError(t, err)
	sameExtra, err := encoding.EncodeShastaExtraData(0, big.NewInt(5)) // same proposal
	require.NoError(t, err)

	nextNewer := &types.Header{Extra: newerExtra}
	nextSame := &types.Header{Extra: sameExtra}

	eventSynced := &rawdb.L1Origin{L1BlockHeight: big.NewInt(100)}
	preconfZero := &rawdb.L1Origin{L1BlockHeight: big.NewInt(0)}
	preconfNil := &rawdb.L1Origin{L1BlockHeight: nil}

	// Preconfirmation candidate (zero or nil L1 height): never sealed.
	sealed, err := evaluateProposalSeal(proposalID, preconfZero, nextNewer)
	require.NoError(t, err)
	require.False(t, sealed)

	sealed, err = evaluateProposalSeal(proposalID, preconfNil, nextNewer)
	require.NoError(t, err)
	require.False(t, sealed)

	// Event-synced candidate, boundary block not present yet: not sealed.
	sealed, err = evaluateProposalSeal(proposalID, eventSynced, nil)
	require.NoError(t, err)
	require.False(t, sealed)

	// Event-synced candidate, next block still same proposal: not sealed.
	sealed, err = evaluateProposalSeal(proposalID, eventSynced, nextSame)
	require.NoError(t, err)
	require.False(t, sealed)

	// Event-synced candidate, next block newer proposal: sealed.
	sealed, err = evaluateProposalSeal(proposalID, eventSynced, nextNewer)
	require.NoError(t, err)
	require.True(t, sealed)

	// Beacon-synced candidate (no L1Origin row), next block newer proposal: sealed.
	sealed, err = evaluateProposalSeal(proposalID, nil, nextNewer)
	require.NoError(t, err)
	require.True(t, sealed)

	// Beacon-synced candidate, boundary absent: not sealed.
	sealed, err = evaluateProposalSeal(proposalID, nil, nil)
	require.NoError(t, err)
	require.False(t, sealed)

	// Malformed next-block extraData: propagate error.
	_, err = evaluateProposalSeal(proposalID, eventSynced, &types.Header{Extra: []byte{0x00}})
	require.Error(t, err)
}
