package eventiterator

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"
)

type ProposalIteratorTestSuite struct {
	suite.Suite
}

func TestProposalIteratorTestSuite(t *testing.T) {
	suite.Run(t, new(ProposalIteratorTestSuite))
}

// TestIsNonCanonicalLog guards the regression that allowed the driver to
// process Proposed events from orphaned L1 blocks after a reorg (masaya
// 2026-04-30 incident). The iterator must skip a log whose BlockHash differs
// from the canonical hash at its block number — using HeaderByHash to
// "validate" the log is not a canonicality check, since an RPC node can still
// serve an orphaned block by hash.
func (s *ProposalIteratorTestSuite) TestIsNonCanonicalLog() {
	canonicalHeader := &types.Header{
		Number:     big.NewInt(2_723_815),
		ParentHash: common.HexToHash("0x98c2cd9e5a2b02760ee8fc96072bf6aa0d68504d7604e1ff5536fdc74c29a043"),
	}
	canonicalHash := canonicalHeader.Hash()
	orphanHash := common.HexToHash("0x4e7d0a8c64dcba4d8e3de70e0edb86d28a5fa2b8a4f9b98e3c0d3a3a5e223099")
	s.NotEqual(canonicalHash, orphanHash, "test setup: orphan hash must differ from canonical")

	// Orphaned block hash is non-canonical.
	s.True(isNonCanonicalLog(types.Log{BlockNumber: 2_723_815, BlockHash: orphanHash}, canonicalHeader))

	// Removed flag is non-canonical even when the hash matches.
	s.True(isNonCanonicalLog(
		types.Log{BlockNumber: 2_723_815, BlockHash: canonicalHash, Removed: true},
		canonicalHeader,
	))

	// Matching canonical hash is canonical.
	s.False(isNonCanonicalLog(types.Log{BlockNumber: 2_723_815, BlockHash: canonicalHash}, canonicalHeader))
}
