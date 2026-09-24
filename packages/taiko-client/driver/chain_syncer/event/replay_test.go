package event

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	blocksInserter "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/blocks_inserter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/derivation"
)

func (s *EventSyncerTestSuite) TestReplayWithOmittedTransactionDoesNotReportReorg() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	meta := s.ProposeAndInsertValidBlock(s.p, s.s)
	block, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Require().NoError(err)
	parent, err := s.RPCClient.L2.BlockByHash(ctx, block.ParentHash())
	s.Require().NoError(err)
	_, anchorNumber, _, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(block.Transactions()[0])
	s.Require().NoError(err)
	constructor, err := anchorTxConstructor.New(s.RPCClient)
	s.Require().NoError(err)
	notifications := make(chan *encoding.LastSeenProposal, 3)
	inserter := blocksInserter.NewBlocksInserter(s.RPCClient, s.s.progressTracker, constructor, notifications)
	source := &derivation.DerivationSourcePayload{
		ParentBlock: parent,
		BlockPayloads: []*derivation.BlockPayload{{BlockManifest: manifest.BlockManifest{
			Timestamp:         block.Time(),
			Coinbase:          block.Coinbase(),
			AnchorBlockNumber: anchorNumber,
			GasLimit:          block.GasLimit() - consensus.AnchorV3V4GasLimit,
			Transactions:      append(types.Transactions{}, block.Transactions()[1:]...),
		}}},
	}

	// A nonce gap makes this extra input transaction ineligible for execution.
	// Building with it must still yield the original block, but a different payload ID.
	nonce, err := s.RPCClient.L2.NonceAt(ctx, s.TestAddr, block.Number())
	s.Require().NoError(err)
	omitted, err := types.SignTx(types.NewTransaction(
		nonce+100, common.Address{1}, common.Big0, 21_000, big.NewInt(10_000_000_000), nil,
	), types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Require().NoError(err)
	source.BlockPayloads[0].Transactions = append(source.BlockPayloads[0].Transactions, omitted)
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	s.receiveReplayNotification(ctx, notifications)
	originalOrigin, err := s.RPCClient.L2.L1OriginByID(ctx, block.Number())
	s.Require().NoError(err)
	afterOriginal, err := s.RPCClient.L2.HeaderByNumber(ctx, block.Number())
	s.Require().NoError(err)
	s.Require().Equal(block.Hash(), afterOriginal.Hash())

	// Recovery uses only the transactions that made it into the block.
	source.BlockPayloads[0].Transactions = block.Transactions()[1:]
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	completion := s.receiveReplayNotification(ctx, notifications)
	recoveredOrigin, err := s.RPCClient.L2.L1OriginByID(ctx, block.Number())
	s.Require().NoError(err)
	s.NotEqual(originalOrigin.BuildPayloadArgsID, recoveredOrigin.BuildPayloadArgsID)
	s.False(completion.PreconfChainReorged, "same-hash replay must not be reported as a reorg")
	afterReplay, err := s.RPCClient.L2.HeaderByNumber(ctx, block.Number())
	s.Require().NoError(err)
	s.Equal(block.Hash(), afterReplay.Hash())

	// Changing a header field really replaces the canonical block at this height.
	source.BlockPayloads[0].Coinbase = common.Address{2}
	_, err = inserter.InsertBlocksWithManifest(ctx, meta, source, nil)
	s.Require().NoError(err)
	s.True(s.receiveReplayNotification(ctx, notifications).PreconfChainReorged)
	replacement, err := s.RPCClient.L2.HeaderByNumber(ctx, block.Number())
	s.Require().NoError(err)
	s.NotEqual(block.Hash(), replacement.Hash())
}

func (s *EventSyncerTestSuite) receiveReplayNotification(
	ctx context.Context,
	notifications <-chan *encoding.LastSeenProposal,
) *encoding.LastSeenProposal {
	s.T().Helper()
	select {
	case proposal := <-notifications:
		return proposal
	case <-ctx.Done():
		s.T().Fatal("timed out waiting for proposal completion")
		return nil
	}
}
