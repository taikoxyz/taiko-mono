package driver

import (
	"bytes"
	"context"
	"math/big"
	"net/http"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/go-resty/resty/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event"
	preconfblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
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
	s.Require().NotZero(lastUnzen.Transactions().Len())
	s.True(bytes.HasPrefix(lastUnzen.Transactions()[0].Data(), consensus.AnchorV4Selector))
	s.Require().NotNil(lastUnzen.BeaconRoot())
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
		s.False(bytes.HasPrefix(tx.Data(), consensus.AnchorV4Selector))
	}
	s.Equal(lastUnzen.GasLimit()-consensus.AnchorV3V4GasLimit, firstEtna.GasLimit())
	s.Require().NotNil(firstEtna.BeaconRoot())
	firstAnchor := s.AnchorBlockNumberOf(firstEtna)
	s.Greater(firstAnchor, unzenAnchor)
	canonicalAnchor, err := s.RPCClient.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(firstAnchor))
	s.Nil(err)
	s.Equal(canonicalAnchor.Hash(), *firstEtna.BeaconRoot())
	// The anchor block number now comes from the L1 block the root names, while the Anchor contract, which no
	// Etna block calls, still holds the last Unzen anchor.
	anchorState, err := s.RPCClient.ShastaClients.Anchor.GetBlockState(
		&bind.CallOpts{BlockHash: firstEtna.Hash(), Context: ctx},
	)
	s.Nil(err)
	s.Equal(unzenAnchor, anchorState.AnchorBlockNumber.Uint64())

	// 4. An invalid derivation source falls back to the default manifest: an empty Etna block that
	//    inherits its Etna parent's anchor, so it repeats the parent's root.
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
	s.Require().NotNil(parent.BeaconRoot())
	s.Require().NotNil(defaultBlock.BeaconRoot())
	s.Equal(*parent.BeaconRoot(), *defaultBlock.BeaconRoot())
	s.Equal(parent.GasLimit(), defaultBlock.GasLimit())
	// The prover reports this as the next proposal's last anchor block number through the same lookup
	// (rpc.EtnaAnchorBlockNumber), and it must not be the frozen Anchor contract value.
	s.Equal(s.AnchorBlockNumberOf(parent), s.AnchorBlockNumberOf(defaultBlock))
	s.GreaterOrEqual(s.AnchorBlockNumberOf(defaultBlock), firstAnchor)

	// 5. Resetting the L1 cursor moves it back to the anchor of the previous proposal's last block: read from
	//    the anchor transaction when that block is Unzen, and resolved from its root when it is Etna. From the
	//    Etna anchor, a fresh event syncer, as after a restart, re-derives both Etna proposals. Each must be
	//    detected as already known: the inserter reports it with PreconfChainReorged false, which it only does
	//    for a known proposal (a rebuilt one is reported true), and the chain head stays the same.
	s.Nil(s.d.state.ResetL1Current(ctx, firstEtna.Number()))
	s.Equal(unzenAnchor, s.d.state.GetL1Current().Number.Uint64())
	s.Nil(s.d.state.ResetL1Current(ctx, defaultBlock.Number()))
	s.Equal(firstAnchor, s.d.state.GetL1Current().Number.Uint64())
	latestSeenProposalCh := make(chan *encoding.LastSeenProposal, 2)
	restartedSyncer, err := event.NewSyncer(
		ctx,
		s.RPCClient,
		s.d.state,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2),
		s.ParseL1HttpURLFromEnv(),
		latestSeenProposalCh,
	)
	s.Nil(err)
	s.Nil(restartedSyncer.ProcessL1Blocks(ctx))
	var lastBlockIDs []uint64
	for i := 0; i < 2; i++ {
		select {
		case proposal := <-latestSeenProposalCh:
			s.False(proposal.PreconfChainReorged)
			lastBlockIDs = append(lastBlockIDs, proposal.LastBlockID)
		case <-time.After(10 * time.Second):
			s.FailNow("timed out waiting for a re-derived proposal")
		}
	}
	s.ElementsMatch([]uint64{firstEtna.NumberU64(), defaultBlock.NumberU64()}, lastBlockIDs)
	head, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	s.Equal(defaultBlock.Hash(), head.Hash())

	// 6. The L1 reorg check accepts the Etna anchors.
	proposalID, err := gethcore.DecodeShastaProposalID(defaultBlock.Extra())
	s.Nil(err)
	res, err := s.RPCClient.CheckL1Reorg(ctx, proposalID)
	s.Nil(err)
	s.False(res.IsReorged)

	// 7. A preconfirmation request with a pre-Etna timestamp passes the request-timestamp guard, so only the
	//    parent guard can reject it: its parent is the empty Etna block from step 4, which has no anchor
	//    transaction for the handler to read. Both guards run before the handler reads any other field.
	preEtnaTimestamp := gethcore.DevnetEtnaTime - 1
	s.False(rpc.IsEtna(chainID, preEtnaTimestamp))
	s.True(rpc.IsEtna(chainID, defaultBlock.Time()))
	preconfRes, err := resty.New().R().SetBody(&preconfblocks.BuildPreconfBlockRequestBody{
		ExecutableData: &preconfblocks.ExecutableData{
			ParentHash: defaultBlock.Hash(),
			Number:     defaultBlock.NumberU64() + 1,
			Timestamp:  preEtnaTimestamp,
		},
	}).Post(s.preconfServerURL.String() + "/preconfBlocks")
	s.Nil(err)
	s.Equal(http.StatusBadRequest, preconfRes.StatusCode())
	s.Contains(preconfRes.String(), preconf.ErrNotSupportedAfterEtna.Error())
	headAfter, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)
	s.Equal(defaultBlock.Hash(), headAfter.Hash())
}
