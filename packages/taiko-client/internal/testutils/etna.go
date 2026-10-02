package testutils

import (
	"context"

	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// IsEtnaBlock reports whether the given L2 header belongs to the Etna fork on the test devnet.
func (s *ClientTestSuite) IsEtnaBlock(header *types.Header) bool {
	return rpc.IsEtna(s.RPCClient.L2.ChainID, header.Time)
}

// AnchorTxCount returns how many anchor transactions an L2 block carries: one before Etna, none from
// Etna on. Use it as the index of a block's first user transaction.
func (s *ClientTestSuite) AnchorTxCount(header *types.Header) int {
	if s.IsEtnaBlock(header) {
		return 0
	}
	return 1
}

// AnchorBlockNumberOf returns the L1 block an L2 block anchors to: decoded from its anchor transaction
// before Etna, resolved from its parentBeaconBlockRoot from Etna on.
func (s *ClientTestSuite) AnchorBlockNumberOf(block *types.Block) uint64 {
	if s.IsEtnaBlock(block.Header()) {
		anchorBlockNumber, err := s.RPCClient.EtnaAnchorBlockNumber(context.Background(), block.Header())
		s.Nil(err)
		return anchorBlockNumber
	}

	_, anchorBlockNumber, _, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(block.Transactions()[0])
	s.Nil(err)
	return anchorBlockNumber
}

// SkipPreconfUnderEtna skips a preconfirmation test when the next L2 block would be an Etna block,
// because preconfirmation does not support Etna yet.
func (s *ClientTestSuite) SkipPreconfUnderEtna() {
	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	if rpc.IsEtna(s.RPCClient.L2.ChainID, head.Time+1) {
		s.T().Skip("preconfirmation is not supported after Etna yet")
	}
}
