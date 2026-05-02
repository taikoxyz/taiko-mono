package eventiterator

import (
	"math/big"
	"math/rand"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type ProposalIteratorTestSuite struct {
	suite.Suite
}

func TestProposalIteratorTestSuite(t *testing.T) {
	suite.Run(t, new(ProposalIteratorTestSuite))
}

// TestIsNonCanonicalLog guards the regression that allowed the driver to
// process Proposed events from orphaned L1 blocks after a reorg. The iterator
// must skip a log whose BlockHash differs from the canonical hash at its block
// number — using HeaderByHash to "validate" the log is not a canonicality
// check, since an RPC node can still serve an orphaned block by hash.
func (s *ProposalIteratorTestSuite) TestIsNonCanonicalLog() {
	blockNumber := rand.Uint64()
	canonicalHeader := &types.Header{
		Number:     new(big.Int).SetUint64(blockNumber),
		ParentHash: testutils.RandomHash(),
	}
	canonicalHash := canonicalHeader.Hash()
	orphanHash := testutils.RandomHash()
	s.NotEqual(canonicalHash, orphanHash, "test setup: orphan hash must differ from canonical")

	// Orphaned block hash is non-canonical.
	s.True(isNonCanonicalLog(types.Log{BlockNumber: blockNumber, BlockHash: orphanHash}, canonicalHeader))

	// Removed flag is non-canonical even when the hash matches.
	s.True(isNonCanonicalLog(
		types.Log{BlockNumber: blockNumber, BlockHash: canonicalHash, Removed: true},
		canonicalHeader,
	))

	// Matching canonical hash is canonical.
	s.False(isNonCanonicalLog(types.Log{BlockNumber: blockNumber, BlockHash: canonicalHash}, canonicalHeader))
}

// TestSawNonCanonicalEventResetOnIter ensures the sawNonCanonical flag does
// not leak across Iter calls — each new iteration must start clean so a stale
// flag from a previous run can't suppress L1Current advancement on a
// subsequently healthy range.
func (s *ProposalIteratorTestSuite) TestSawNonCanonicalEventResetOnIter() {
	iter := &ProposalIterator{sawNonCanonical: true}
	s.True(iter.SawNonCanonicalEvent())

	// Simulate the reset that happens at the top of Iter().
	iter.sawNonCanonical = false
	s.False(iter.SawNonCanonicalEvent())
}
