package prover

import (
	"context"
	"errors"
	"math/big"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	state "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/shared_state"
)

type stubReorgChecker struct {
	result        *rpc.ReorgCheckResult
	err           error
	gotProposalID *big.Int
}

func (s *stubReorgChecker) CheckL1Reorg(_ context.Context, proposalID *big.Int) (*rpc.ReorgCheckResult, error) {
	s.gotProposalID = proposalID
	return s.result, s.err
}

func newReorgedProofsError(lowestID uint64, staleL1Height uint64) *proofSubmitter.ReorgedProofsError {
	return &proofSubmitter.ReorgedProofsError{
		LowestProposalID: lowestID,
		LowestProposalMeta: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.ShastaInboxClientProposed{
				Id:  new(big.Int).SetUint64(lowestID),
				Raw: types.Log{BlockNumber: staleL1Height},
			},
			0,
		),
	}
}

func TestReorgRollbackAnchorPrefersCanonicalAnchor(t *testing.T) {
	checker := &stubReorgChecker{
		result: &rpc.ReorgCheckResult{
			IsReorged:                    true,
			L1CurrentToReset:             &types.Header{Number: big.NewInt(50)},
			LastHandledProposalIDToReset: big.NewInt(17),
		},
	}

	resetID, resetHeader, err := resolveReorgRollbackAnchor(context.Background(), checker, newReorgedProofsError(21, 88))

	require.NoError(t, err)
	require.Equal(t, uint64(17), resetID)
	require.Equal(t, uint64(50), resetHeader.Number.Uint64())
	require.Equal(t, uint64(20), checker.gotProposalID.Uint64())
}

func TestReorgRollbackAnchorGenesisResult(t *testing.T) {
	// CheckL1Reorg's genesis branches set IsReorged and L1CurrentToReset, but leave
	// LastHandledProposalIDToReset nil.
	checker := &stubReorgChecker{
		result: &rpc.ReorgCheckResult{
			IsReorged:        true,
			L1CurrentToReset: &types.Header{Number: big.NewInt(0)},
		},
	}

	resetID, resetHeader, err := resolveReorgRollbackAnchor(context.Background(), checker, newReorgedProofsError(1, 88))

	require.NoError(t, err)
	require.Equal(t, uint64(0), resetID)
	require.Equal(t, uint64(0), resetHeader.Number.Uint64())
}

func TestReorgRollbackAnchorFallsBackOnCheckerError(t *testing.T) {
	checker := &stubReorgChecker{err: errors.New("RPC unavailable")}

	resetID, resetHeader, err := resolveReorgRollbackAnchor(context.Background(), checker, newReorgedProofsError(21, 88))

	require.NoError(t, err)
	require.Equal(t, uint64(20), resetID)
	require.Equal(t, uint64(88), resetHeader.Number.Uint64())
}

func TestReorgRollbackAnchorFallsBackOnUnresolvedResult(t *testing.T) {
	// A P2P-synced L2 EE without L1Origin data makes CheckL1Reorg skip its walk and return
	// an empty result.
	checker := &stubReorgChecker{result: new(rpc.ReorgCheckResult)}

	resetID, resetHeader, err := resolveReorgRollbackAnchor(context.Background(), checker, newReorgedProofsError(21, 88))

	require.NoError(t, err)
	require.Equal(t, uint64(20), resetID)
	require.Equal(t, uint64(88), resetHeader.Number.Uint64())
}

func TestReorgRollbackAnchorRejectsInvalidInput(t *testing.T) {
	checker := &stubReorgChecker{err: errors.New("RPC unavailable")}

	_, _, err := resolveReorgRollbackAnchor(context.Background(), checker, nil)
	require.Error(t, err)

	_, _, err = resolveReorgRollbackAnchor(context.Background(), checker, newReorgedProofsError(0, 88))
	require.Error(t, err)

	// Fallback with unusable metadata must not fabricate an anchor.
	_, _, err = resolveReorgRollbackAnchor(context.Background(), checker, &proofSubmitter.ReorgedProofsError{
		LowestProposalID: 21,
	})
	require.Error(t, err)

	_, _, err = resolveReorgRollbackAnchor(context.Background(), checker, newReorgedProofsError(21, 0))
	require.Error(t, err)
}

func TestRollbackProposalCursorForReorgLowersCursors(t *testing.T) {
	p := &Prover{
		ctx:         context.Background(),
		cfg:         &Config{},
		sharedState: state.New(),
	}
	p.sharedState.SetLastHandledProposalID(42)
	p.sharedState.SetL1Current(&types.Header{Number: big.NewInt(100)})
	checker := &stubReorgChecker{
		result: &rpc.ReorgCheckResult{
			IsReorged:                    true,
			L1CurrentToReset:             &types.Header{Number: big.NewInt(50)},
			LastHandledProposalIDToReset: big.NewInt(17),
		},
	}

	require.NoError(t, p.rollbackProposalCursorForReorg(checker, newReorgedProofsError(21, 88)))

	require.Equal(t, uint64(17), p.sharedState.GetLastHandledProposalID())
	require.Equal(t, uint64(50), p.sharedState.GetL1Current().Number.Uint64())
}

func TestRollbackProposalCursorForReorgNeverAdvancesCursors(t *testing.T) {
	p := &Prover{
		ctx:         context.Background(),
		cfg:         &Config{},
		sharedState: state.New(),
	}
	p.sharedState.SetLastHandledProposalID(10)
	p.sharedState.SetL1Current(&types.Header{Number: big.NewInt(30)})
	checker := &stubReorgChecker{
		result: &rpc.ReorgCheckResult{
			IsReorged:                    true,
			L1CurrentToReset:             &types.Header{Number: big.NewInt(50)},
			LastHandledProposalIDToReset: big.NewInt(17),
		},
	}

	require.NoError(t, p.rollbackProposalCursorForReorg(checker, newReorgedProofsError(21, 88)))

	require.Equal(t, uint64(10), p.sharedState.GetLastHandledProposalID())
	require.Equal(t, uint64(30), p.sharedState.GetL1Current().Number.Uint64())
}

func TestRollbackProposalCursorForReorgNoopAfterCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	p := &Prover{
		ctx:         ctx,
		cfg:         &Config{},
		sharedState: state.New(),
	}
	p.sharedState.SetLastHandledProposalID(42)
	p.sharedState.SetL1Current(&types.Header{Number: big.NewInt(100)})
	cancel()

	require.NoError(t, p.rollbackProposalCursorForReorg(&stubReorgChecker{}, newReorgedProofsError(21, 88)))

	require.Equal(t, uint64(42), p.sharedState.GetLastHandledProposalID())
	require.Equal(t, uint64(100), p.sharedState.GetL1Current().Number.Uint64())
}

func TestReorgedProofsErrorMatchesInvalidProofSentinel(t *testing.T) {
	err := error(&proofSubmitter.ReorgedProofsError{LowestProposalID: 21})

	// The typed error must keep matching the legacy ErrInvalidProof checks, so callers
	// missing the typed branch fall back to the previous drop behavior.
	require.ErrorIs(t, err, proofSubmitter.ErrInvalidProof)
	require.True(t, strings.Contains(err.Error(), proofSubmitter.ErrInvalidProof.Error()))

	var reorgedErr *proofSubmitter.ReorgedProofsError
	require.True(t, errors.As(err, &reorgedErr))
	require.Equal(t, uint64(21), reorgedErr.LowestProposalID)
}
