package driver

import (
	"bytes"
	"context"
	"math/big"
	"os"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/consensus/taiko"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

// TestEtnaBoundary crosses the Unzen → Etna boundary. It only runs in the dedicated CI job that sets
// TAIKO_TEST_ETNA_BOUNDARY: that devnet activates Etna one hour after the L1 start timestamp (see
// integration_test/entrypoint.sh), and the test moves L1 time across it.
func (s *DriverTestSuite) TestEtnaBoundary() {
	if os.Getenv("TAIKO_TEST_ETNA_BOUNDARY") != "true" {
		s.T().Skip("only runs in the Etna boundary job (TAIKO_TEST_ETNA_BOUNDARY=true)")
	}
	var (
		ctx         = context.Background()
		chainID     = s.RPCClient.L2.ChainID
		eventSyncer = s.d.ChainSyncer().EventSyncer()
	)

	// 1. Before the boundary, blocks still start with the anchor transaction and commit a zero root.
	s.ProposeAndInsertValidBlock(s.p, eventSyncer)
	lastUnzen, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	s.False(rpc.IsEtna(chainID, lastUnzen.Time()))
	s.Equal(1, s.AnchorTxCount(lastUnzen.Header()))
	s.Equal(common.Hash{}, *lastUnzen.BeaconRoot())
	unzenAnchor := s.AnchorBlockNumberOf(lastUnzen)

	// 2. Move L1 time to the Etna activation timestamp.
	l1Head, err := s.RPCClient.L1.HeaderByNumber(ctx, nil)
	s.Nil(err)
	s.Less(l1Head.Time, gethcore.DevnetEtnaTime)
	s.SetNextBlockTimestamp(gethcore.DevnetEtnaTime)
	s.L1Mine()

	// 3. The first Etna block has no anchor transaction, commits its L1 anchor block hash, and drops the
	//    anchor gas reserve its Unzen parent still carries.
	s.ProposeAndInsertValidBlock(s.p, eventSyncer)
	firstEtna, err := s.RPCClient.L2.BlockByNumber(ctx, new(big.Int).Add(lastUnzen.Number(), common.Big1))
	s.Nil(err)
	s.True(rpc.IsEtna(chainID, firstEtna.Time()))
	for _, tx := range firstEtna.Transactions() {
		s.False(bytes.HasPrefix(tx.Data(), taiko.AnchorV4Selector))
	}
	s.Equal(lastUnzen.GasLimit()-rpc.AnchorGasReserve(chainID, lastUnzen.Time()), firstEtna.GasLimit())
	s.NotNil(firstEtna.BeaconRoot())
	firstAnchor := s.AnchorBlockNumberOf(firstEtna)
	s.GreaterOrEqual(firstAnchor, unzenAnchor)
	canonicalAnchor, err := s.RPCClient.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(firstAnchor))
	s.Nil(err)
	s.Equal(canonicalAnchor.Hash(), *firstEtna.BeaconRoot())

	// 4. An invalid derivation source falls back to the default manifest: an empty Etna block that
	//    inherits its Etna parent's anchor, so it repeats the parent's root (R1).
	parent, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	txCandidate, err := builder.NewBlobTransactionBuilder(
		s.RPCClient,
		common.HexToAddress(os.Getenv("INBOX")),
		common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		10_000_000,
	).Build(ctx, []types.Transactions{{}})
	s.Nil(err)
	txCandidate.Blobs, err = builder.SplitToBlobs([]byte{0x1})
	s.Nil(err)
	s.L1Mine()
	_, err = s.TxMgr("proposer", s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")).Send(ctx, *txCandidate)
	s.Nil(err)
	s.Nil(eventSyncer.ProcessL1Blocks(ctx))

	defaultBlock, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	s.Equal(parent.NumberU64()+1, defaultBlock.NumberU64())
	s.Zero(defaultBlock.Transactions().Len())
	s.Zero(defaultBlock.Difficulty().Sign())
	s.Equal(*parent.BeaconRoot(), *defaultBlock.BeaconRoot())
	s.Equal(parent.GasLimit(), defaultBlock.GasLimit())
	// The prover reports this as the next proposal's last anchor block number through the same lookup
	// (rpc.EtnaAnchorBlockNumber), and it must not be the frozen Anchor contract value.
	s.Equal(s.AnchorBlockNumberOf(parent), s.AnchorBlockNumberOf(defaultBlock))
	s.GreaterOrEqual(s.AnchorBlockNumberOf(defaultBlock), firstAnchor)

	// 5. Re-deriving the Etna proposals after resetting the L1 cursor finds every block already known. The
	//    cursor moves back to the Etna anchor of the previous proposal's last block. The driver's own syncer
	//    skips proposals it has already inserted, so a fresh one, as after a restart, re-derives them.
	s.Nil(s.d.state.ResetL1Current(ctx, defaultBlock.Number()))
	s.Equal(firstAnchor, s.d.state.GetL1Current().Number.Uint64())
	restartedSyncer, err := event.NewSyncer(
		ctx,
		s.RPCClient,
		s.d.state,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2),
		s.ParseL1HttpURLFromEnv(),
		nil,
	)
	s.Nil(err)
	s.Nil(restartedSyncer.ProcessL1Blocks(ctx))
	head, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	s.Equal(defaultBlock.Hash(), head.Hash())

	// 6. The L1 reorg check accepts the Etna anchors.
	proposalID, err := gethcore.DecodeShastaProposalID(defaultBlock.Extra())
	s.Nil(err)
	res, err := s.RPCClient.CheckL1Reorg(ctx, proposalID)
	s.Nil(err)
	s.False(res.IsReorged)
}
