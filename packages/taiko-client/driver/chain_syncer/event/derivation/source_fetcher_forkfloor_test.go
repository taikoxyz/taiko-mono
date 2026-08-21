package derivation

import (
	"testing"

	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// TestComputeTimestampLowerBoundShastaForkFloor is the standalone regression test for audit finding
// D2: the derivation timestamp lower bound must include the Shasta fork-time floor so the Go driver
// agrees with the derivation spec and the Rust driver / raiko2 / gaiko2 provers at a non-genesis
// fork activation. ComputeTimestampLowerBound is a pure function, so this test needs no live devnet
// and runs in isolation (unlike the DerivationSourceFetcherTestSuite methods, whose SetupTest dials
// a live L1/L2 devnet).
func TestComputeTimestampLowerBoundShastaForkFloor(t *testing.T) {
	// Hoodi activates Shasta at a non-genesis timestamp T.
	chainID := params.TaikoHoodiNetworkID
	forkTime := manifest.ShastaForkTimeByChainID(chainID)
	offset := manifest.TimestampMaxOffsetByChainID(chainID)

	// Precondition: the fork time sits well above the max offset, so the scenario below (both
	// non-fork constraints falling strictly under the fork time) is meaningful.
	require.Greater(t, forkTime, offset)

	// parent.ts = T-2, proposal.ts = T+20: a parent just before the fork and a proposal shortly
	// after. Both non-fork constraints (parent+1 and proposal-OFFSET) land strictly below T.
	parentTimestamp := forkTime - 2
	proposalTimestamp := forkTime + 20
	require.Less(t, parentTimestamp+1, forkTime)        // parent+1 == T-1 < T
	require.Less(t, proposalTimestamp-offset, forkTime) // proposal-OFFSET < T

	lowerBound := ComputeTimestampLowerBound(parentTimestamp, proposalTimestamp, chainID)

	// The fork-time floor raises the bound to exactly T (not T-1, the buggy pre-fix result).
	require.Equal(t, forkTime, lowerBound)
	require.NotEqual(t, parentTimestamp+1, lowerBound)

	// Genesis-activated chains (Shasta fork time == 0) are unaffected: the floor is a no-op and the
	// bound remains max(parent+1, proposal-TIMESTAMP_MAX_OFFSET).
	devnetID := params.TaikoInternalNetworkID
	require.Zero(t, manifest.ShastaForkTimeByChainID(devnetID))

	devnetParent := uint64(100)
	devnetProposal := uint64(10_000)
	expectedDevnetBound := max(devnetParent+1, devnetProposal-manifest.TimestampMaxOffsetByChainID(devnetID))
	require.Equal(t, expectedDevnetBound, ComputeTimestampLowerBound(devnetParent, devnetProposal, devnetID))
}
