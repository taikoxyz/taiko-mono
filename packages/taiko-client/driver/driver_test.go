package driver

import (
	"context"
	"fmt"
	"math/big"
	"math/rand"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/go-resty/resty/v2"
	"github.com/holiman/uint256"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	anchortxconstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	blocksInserter "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/blocks_inserter"
	preconfblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
)

type DriverTestSuite struct {
	testutils.ClientTestSuite
	cancel           context.CancelFunc
	p                *proposer.Proposer
	d                *Driver
	preconfServerURL *url.URL
}

func (s *DriverTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	// InitFromConfig driver
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	d := new(Driver)
	ctx, cancel := context.WithCancel(context.Background())

	// Get default in-memory db p2p configs
	p2pConfig, p2pSignerConfig := s.defaultCliP2PConfigs()
	preconfServerPort := uint64(testutils.RandomPort())

	s.Nil(d.InitFromConfig(ctx, &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:         os.Getenv("L1_WS"),
			L2Endpoint:         os.Getenv("L2_WS"),
			L2EngineEndpoint:   os.Getenv("L2_AUTH"),
			PacayaInboxAddress: common.HexToAddress(os.Getenv("PACAYA_INBOX")),
			ShastaInboxAddress: common.HexToAddress(os.Getenv("SHASTA_INBOX")),
			TaikoAnchorAddress: common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			JwtSecret:          string(jwtSecret),
		},
		BlobServerEndpoint:     s.BlobServer.URL(),
		P2PConfigs:             p2pConfig,
		P2PSignerConfigs:       p2pSignerConfig,
		PreconfBlockServerPort: preconfServerPort,
	}))
	s.d = d
	s.cancel = cancel
	if s.d.preconfBlockServer != nil {
		s.d.preconfBlockServer.SetSyncReady(true)
	}

	go func() {
		if err := s.d.preconfBlockServer.Start(preconfServerPort); err != nil {
			log.Error("Failed to start preconfirmation block server", "port", preconfServerPort, "error", err)
		}
	}()

	url, err := url.Parse(fmt.Sprintf("http://localhost:%v", preconfServerPort))
	s.Nil(err)
	s.preconfServerURL = url

	// InitFromConfig proposer
	s.InitProposer()
}

func (s *DriverTestSuite) TestName() {
	s.Equal("driver", s.d.Name())
}

func (s *DriverTestSuite) TestProcessL1Blocks() {
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	// Propose a valid L2 block
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	// Empty blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())
	s.Nil(err)

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head3.Number.Uint64(), l2Head2.Number.Uint64())

	for _, height := range []uint64{l2Head3.Number.Uint64(), l2Head3.Number.Uint64() - 1} {
		header, err := s.d.rpc.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(height))
		s.Nil(err)

		txCount, err := s.d.rpc.L2.TransactionCount(context.Background(), header.Hash())
		s.Nil(err)
		s.GreaterOrEqual(txCount, uint(1))

		anchorTx, err := s.d.rpc.L2.TransactionInBlock(context.Background(), header.Hash(), 0)
		s.Nil(err)

		var method *abi.Method
		method, err = encoding.TaikoAnchorABI.MethodById(anchorTx.Data())
		s.Nil(err)
		s.Contains(method.Name, "anchor")
	}
}

func (s *DriverTestSuite) TestCheckL1ReorgToHigherFork() {
	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())

	m := s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	headL1Origin, err := s.RPCClient.L2Engine.LastL1OriginByBatchID(context.Background(), m.Shasta().GetEventData().Id)
	s.Nil(err)
	s.Equal(l2Head2.Hash(), headL1Origin.L2BlockHash)

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		m.Shasta().GetEventData().Id,
		true,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	// Because of evm_revert operation, the nonce of the proposer need to be adjusted.
	// Propose ten blocks on another fork
	for i := 0; i < 10; i++ {
		s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())
	}

	l1Head4, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l1Head4.Number.Uint64(), l1Head2.Number.Uint64())

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(l2Head1.Number.Uint64()+10, l2Head3.Number.Uint64())

	parent, err := s.d.rpc.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(l2Head1.Number.Uint64()+1))
	s.Nil(err)
	s.Equal(parent.ParentHash, l2Head1.Hash())
	s.NotEqual(parent.Hash(), l2Head2.ParentHash)
}

func (s *DriverTestSuite) TestCheckL1ReorgToLowerFork() {
	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())
	time.Sleep(3 * time.Second)
	m := s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	headL1Origin, err := s.RPCClient.L2Engine.LastL1OriginByBatchID(context.Background(), m.Shasta().GetEventData().Id)
	s.Nil(err)
	s.Equal(l2Head2.Hash(), headL1Origin.L2BlockHash)

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		m.Shasta().GetEventData().Id,
		true,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	l1Head3, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.GreaterOrEqual(l1Head3.Number.Uint64(), l1Head1.Number.Uint64())

	// Propose one blocks on another fork
	s.ProposeValidBlock(s.p)

	l1Head4, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l1Head4.Number.Uint64(), l1Head3.Number.Uint64())
	s.Less(l1Head4.Number.Uint64(), l1Head2.Number.Uint64())

	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	parent, err := s.d.rpc.L2.HeaderByHash(context.Background(), l2Head3.ParentHash)
	s.Nil(err)
	s.Equal(l2Head3.Number.Uint64(), l2Head2.Number.Uint64()-1)
	s.Equal(parent.Hash(), l2Head1.Hash())
}

func (s *DriverTestSuite) TestCheckL1ReorgShastaToPacaya() {
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Less(l2Head1.Time, s.RPCClient.ShastaClients.ForkTime)
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())
	testnetL1SnapshotID := s.SetL1Snapshot()

	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Less(l2Head2.Time, s.RPCClient.ShastaClients.ForkTime)
	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())

	var m metadata.TaikoProposalMetaData
	for i := 0; i < 5; i++ {
		m = s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())
	}

	s.True(m.IsShasta())
	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head3.Time, s.RPCClient.ShastaClients.ForkTime)

	headL1Origin, err := s.RPCClient.L2Engine.LastL1OriginByBatchID(context.Background(), m.Shasta().GetEventData().Id)
	s.Nil(err)
	s.Equal(l2Head3.Hash(), headL1Origin.L2BlockHash)

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(context.Background(), m.Shasta().GetEventData().Id, true)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.L1Mine()
	s.InitProposer()

	l1Head3, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l1Head3.Number.Uint64(), l1Head1.Number.Uint64()+1)
	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	s.ProposeValidBlock(s.p)
	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))
	s.L1Mine()

	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())

	l2Head4, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head4.Time, s.RPCClient.ShastaClients.ForkTime)

	s.InitShastaGenesisProposal()

	for i := 0; i < 2; i++ {
		s.ProposeValidBlock(s.p)
	}
	s.L1Mine()

	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	l2Head5, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head4.Number.Uint64()+2, l2Head5.Number.Uint64())
}

func (s *DriverTestSuite) TestCheckL1ReorgToSameHeightFork() {
	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())

	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())
	time.Sleep(3 * time.Second)
	m := s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	headL1Origin, err := s.RPCClient.L2Engine.LastL1OriginByBatchID(context.Background(), m.Shasta().GetEventData().Id)
	s.Nil(err)
	s.Equal(l2Head2.Hash(), headL1Origin.L2BlockHash)

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		m.Shasta().GetEventData().Id,
		true,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	l1Head3, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.GreaterOrEqual(l1Head3.Number.Uint64(), l1Head1.Number.Uint64())

	// Propose two blocks on another fork
	s.ProposeValidBlock(s.p)
	time.Sleep(3 * time.Second)
	s.ProposeValidBlock(s.p)

	l1Head4, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l1Head4.Number.Uint64(), l1Head3.Number.Uint64())

	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	parent, err := s.d.rpc.L2.HeaderByHash(context.Background(), l2Head3.ParentHash)
	s.Nil(err)
	s.Equal(l2Head3.Number.Uint64(), l2Head2.Number.Uint64())
	s.NotEqual(l2Head3.Hash(), l2Head2.Hash())
	s.Equal(parent.ParentHash, l2Head1.Hash())
}

func (s *DriverTestSuite) TestDoSyncNoNewL2Blocks() {
	s.Nil(s.d.l2ChainSyncer.Sync())
}

func (s *DriverTestSuite) TestForcedInclusion() {
	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	forcedInclusionTx, err := testutils.AssembleAndSendTestTx(
		s.RPCClient.L2,
		s.TestAddrPrivKey,
		nonce,
		&s.TestAddr,
		common.Big0,
		[]byte{},
	)
	if err != nil {
		s.Equal("replacement transaction underpriced", err.Error())
	}
	b, err := utils.EncodeAndCompressTxList([]*types.Transaction{forcedInclusionTx})
	s.Nil(err)
	s.NotEmpty(b)

	var blob = &eth.Blob{}
	s.Nil(blob.FromData(b))
	data, err := encoding.ForcedInclusionStoreABI.Pack("storeForcedInclusion", uint8(0), uint32(0), uint32(len(b)))
	s.Nil(err)

	feeInGwei, err := s.RPCClient.PacayaClients.ForcedInclusionStore.FeeInGwei(nil)
	s.Nil(err)

	receipt, err := s.TxMgr("storeForcedInclusion", s.KeyFromEnv("TEST_ACCOUNT_PRIVATE_KEY")).Send(
		context.Background(),
		txmgr.TxCandidate{
			TxData: data,
			To:     &s.p.ForcedInclusionStoreAddress,
			Blobs:  []*eth.Blob{blob},
			Value:  new(big.Int).SetUint64(feeInGwei * params.GWei),
		},
	)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	delay, err := s.RPCClient.PacayaClients.ForcedInclusionStore.InclusionDelay(nil)
	s.Nil(err)
	s.NotZero(delay)

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose an empty batch, should with another batch with the forced inclusion tx.
	s.Nil(s.p.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(s.d.l2ChainSyncer.EventSyncer().ProcessL1Blocks(context.Background()))

	l2Head2, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64()+2, l2Head2.Number().Uint64())
	s.Equal(1, len(l2Head2.Transactions()))

	forcedIncludedBlock, err := s.d.rpc.L2.BlockByNumber(
		context.Background(),
		new(big.Int).Add(l2Head1.Number, common.Big1),
	)
	s.Nil(err)
	s.Equal(2, len(forcedIncludedBlock.Transactions()))
	s.Equal(forcedInclusionTx.Hash(), forcedIncludedBlock.Transactions()[1].Hash())

	// Propose an empty batch, without another batch with the forced inclusion tx.
	s.Nil(s.p.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(s.d.l2ChainSyncer.EventSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64()+1, l2Head3.Number().Uint64())
	s.Equal(1, len(l2Head3.Transactions()))
}

func (s *DriverTestSuite) TestL1Current() {
	// propose and insert a block
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())
	// reset L1 current with increased height
	s.Nil(s.d.state.ResetL1Current(s.d.ctx, common.Big1))
}

func (s *DriverTestSuite) TestInsertPreconfBlocks() {
	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	res, err := resty.New().R().Get(s.preconfServerURL.String() + "/healthz")
	s.Nil(err)
	s.True(res.IsSuccess())

	// Try to insert two preconfirmation blocks
	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head1.Number.Uint64()+1, l1Head1.Time).IsSuccess())
	l2Head2, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(2, len(l2Head2.Transactions()))

	l1Origin, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head1.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64(), l1Origin.BlockID.Uint64())
	s.Equal(l2Head2.Hash(), l1Origin.L2BlockHash)
	s.Equal(common.Hash{}, l1Origin.L1BlockHash)
	s.True(l1Origin.IsPreconfBlock())

	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head1.Number.Uint64()+2, l1Head1.Time).IsSuccess())
	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(2, len(l2Head3.Transactions()))

	l1Origin2, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head1.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64(), l1Origin2.BlockID.Uint64())
	s.Equal(l2Head2.Hash(), l1Origin2.L2BlockHash)
	s.Equal(common.Hash{}, l1Origin2.L1BlockHash)
	s.True(l1Origin2.IsPreconfBlock())
}

func (s *DriverTestSuite) TestInsertPreconfBlocksNotReorg() {
	s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	res, err := resty.New().R().Get(s.preconfServerURL.String() + "/healthz")
	s.Nil(err)
	s.True(res.IsSuccess())

	// Try to insert two preconfirmation blocks
	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head1.Number.Uint64()+1, l1Head1.Time).IsSuccess())
	l2Head2, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(2, len(l2Head2.Transactions()))

	l1Origin, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head1.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64(), l1Origin.BlockID.Uint64())
	s.Equal(l2Head2.Hash(), l1Origin.L2BlockHash)
	s.Equal(common.Hash{}, l1Origin.L1BlockHash)
	s.True(l1Origin.IsPreconfBlock())

	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head2.Number().Uint64()+1, l1Head1.Time).IsSuccess())
	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64()+1, l2Head3.Number().Uint64())
	s.Equal(2, len(l2Head3.Transactions()))

	// Propose two same L2 blocks in a batch
	s.proposePreconfBatch(
		[]*types.Block{l2Head2, l2Head3},
		[]*types.Header{l1Head1, l1Head1},
		[]uint8{0, 0},
	)

	l2Head4, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64(), l2Head4.Number().Uint64())
	s.Equal(2, len(l2Head4.Transactions()))

	l1Origin2, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head1.Number, common.Big2))
	s.Nil(err)
	s.Equal(l2Head4.Number().Uint64(), l1Origin2.BlockID.Uint64())
	s.Equal(l2Head4.Hash(), l1Origin2.L2BlockHash)
	s.Equal(l2Head3.Hash(), l1Origin2.L2BlockHash)
	s.NotEqual(common.Hash{}, l1Origin2.L1BlockHash)
	s.False(l1Origin2.IsPreconfBlock())

	canonicalL1Origin, err := s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l1Origin2, canonicalL1Origin)
	s.Equal(l2Head4.Number().Uint64(), canonicalL1Origin.BlockID.Uint64())
}

func (s *DriverTestSuite) TestOnUnsafeL2Payload() {
	// Propose some valid L2 blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l1Head, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	anchorConstructor, err := anchortxconstructor.New(s.d.rpc)
	s.Nil(err)

	anchorTx, err := anchorConstructor.AssembleAnchorV3Tx(
		context.Background(),
		l1Head.Number,
		l1Head.Root,
		l2Head1,
		s.d.protocolConfig.BaseFeeConfig(),
		[][32]byte{},
		new(big.Int).Add(l2Head1.Number, common.Big1),
		l2Head1.BaseFee,
	)
	s.Nil(err)

	baseFee, overflow := uint256.FromBig(anchorTx.GasFeeCap())
	s.False(overflow)

	b, err := utils.EncodeAndCompressTxList(types.Transactions{anchorTx})
	s.Nil(err)

	payload := &eth.ExecutionPayload{
		ParentHash:    l2Head1.Hash(),
		FeeRecipient:  s.TestAddr,
		PrevRandao:    eth.Bytes32(testutils.RandomHash()),
		BlockNumber:   eth.Uint64Quantity(l2Head1.Number.Uint64() + 1),
		GasLimit:      eth.Uint64Quantity(l2Head1.GasLimit),
		Timestamp:     eth.Uint64Quantity(l1Head.Time + 1),
		ExtraData:     l2Head1.Extra,
		BaseFeePerGas: eth.Uint256Quantity(*baseFee),
		Transactions:  []eth.Data{b},
		Withdrawals:   &types.Withdrawals{},
	}

	s.Nil(s.d.preconfBlockServer.OnUnsafeL2Payload(
		context.Background(),
		peer.ID(testutils.RandomBytes(32)),
		&eth.ExecutionPayloadEnvelope{ExecutionPayload: payload},
	))

	l2Head2, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64()+1, l2Head2.Number().Uint64())
	s.Equal(payload.ParentHash, l2Head2.ParentHash())
	s.Equal(payload.FeeRecipient, l2Head2.Coinbase())
	s.Equal(uint64(payload.GasLimit), l2Head2.GasLimit())
	s.Equal(uint64(payload.Timestamp), l2Head2.Time())
	s.Equal([]byte(payload.ExtraData), l2Head2.Extra())
	s.Zero(anchorTx.GasFeeCap().Cmp(l2Head2.BaseFee()))
	s.Equal(1, len(l2Head2.Transactions()))
	s.Equal(anchorTx.Hash(), l2Head2.Transactions()[0].Hash())
}

func (s *DriverTestSuite) TestInsertPreconfBlocksWithReorg() {
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	res, err := resty.New().R().Get(s.preconfServerURL.String() + "/healthz")
	s.Nil(err)
	s.True(res.IsSuccess())

	// Try to insert four preconfirmation blocks
	var (
		preconfBlocksNum = 4
		preconfBlocks    = make([]*types.Block, preconfBlocksNum)
	)
	for i := 0; i < preconfBlocksNum; i++ {
		s.True(s.insertPreconfBlock(
			s.preconfServerURL,
			l1Head1,
			l2Head1.Number.Uint64()+1+uint64(i),
			l1Head1.Time+uint64(preconfBlocksNum),
		).IsSuccess())
		head, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
		s.Nil(err)

		s.Equal(2, len(head.Transactions()))
		preconfBlocks[i] = head

		l1Origin, err := s.RPCClient.L2.L1OriginByID(
			context.Background(),
			new(big.Int).SetUint64(l2Head1.Number.Uint64()+1+uint64(i)),
		)
		s.Nil(err)
		s.Equal(head.Number().Uint64(), l1Origin.BlockID.Uint64())
		s.Equal(head.Hash(), l1Origin.L2BlockHash)
		s.Equal(common.Hash{}, l1Origin.L1BlockHash)
		s.True(l1Origin.IsPreconfBlock())
	}

	// Propose three same L2 blocks in a batch
	s.proposePreconfBatch(
		preconfBlocks,
		[]*types.Header{l1Head1, l1Head1, l1Head1, l1Head1},
		[]uint8{0, 1, 0, 0},
	)

	l2Head2, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64(), preconfBlocks[len(preconfBlocks)-1].Number().Uint64())
	s.NotEqual(l2Head2.Hash(), preconfBlocks[len(preconfBlocks)-1].Hash())
	s.Equal(2, len(l2Head2.Transactions()))

	l1Origin2, err := s.RPCClient.L2.L1OriginByID(
		context.Background(),
		new(big.Int).SetUint64(l2Head1.Number.Uint64()+uint64(preconfBlocksNum)),
	)
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64(), l1Origin2.BlockID.Uint64())
	s.Equal(l2Head2.Hash(), l1Origin2.L2BlockHash)
	s.Equal(l2Head2.Hash(), l1Origin2.L2BlockHash)
	s.NotEqual(common.Hash{}, l1Origin2.L1BlockHash)
	s.False(l1Origin2.IsPreconfBlock())

	canonicalL1Origin, err := s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l1Origin2, canonicalL1Origin)
	s.Equal(l2Head2.Number().Uint64(), canonicalL1Origin.BlockID.Uint64())
	s.Equal(l2Head2.Hash(), canonicalL1Origin.L2BlockHash)
}

func (s *DriverTestSuite) TestOnUnsafeL2PayloadWithInvalidPayload() {
	// Propose some valid L2 blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	b, err := utils.Compress(testutils.RandomBytes(32))
	s.Nil(err)

	baseFee, overflow := uint256.FromBig(common.Big256)
	s.False(overflow)

	payload := &eth.ExecutionPayload{
		ParentHash:    l2Head1.Hash(),
		FeeRecipient:  s.TestAddr,
		PrevRandao:    eth.Bytes32(testutils.RandomHash()),
		BlockNumber:   eth.Uint64Quantity(l2Head1.Number.Uint64() + 1),
		GasLimit:      eth.Uint64Quantity(l2Head1.GasLimit),
		Timestamp:     eth.Uint64Quantity(time.Now().Unix()),
		ExtraData:     l2Head1.Extra,
		BaseFeePerGas: eth.Uint256Quantity(*baseFee),
		Transactions:  []eth.Data{b},
		Withdrawals:   &types.Withdrawals{},
	}

	s.Nil(s.d.preconfBlockServer.OnUnsafeL2Payload(
		context.Background(),
		peer.ID(testutils.RandomBytes(32)),
		&eth.ExecutionPayloadEnvelope{ExecutionPayload: payload},
	))

	l2Head2, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64(), l2Head2.Number().Uint64())
	s.Equal(l2Head1.Hash(), l2Head2.Hash())
}

func (s *DriverTestSuite) TestGossipMessagesRandomReorgs() {
	if os.Getenv("L2_NODE") != "l2_geth" {
		s.T().Skip("This test is only applicable for L2 Geth node, since it returns blocks in forks when " +
			"querying by hash.")
	}
	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())

	l1Head, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	headL1Origin, err := s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64(), headL1Origin.BlockID.Uint64())

	snapshotID := s.SetL1Snapshot()

	var (
		lenForkA = rand.Intn(6) + 3
		forkA    = make([]*types.Block, 0)
		lenForkB = lenForkA + rand.Intn(3) + 1
		forkB    = make([]*types.Block, 0)
	)

	for i := 0; i < lenForkA; i++ {
		s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().EventSyncer())
	}

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	for i := l2Head1.Number.Uint64() + 1; i <= l2Head2.Number.Uint64(); i++ {
		block, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		s.Nil(err)
		forkA = append(forkA, block)
	}
	s.Equal(l2Head2.Number.Uint64()-l2Head1.Number.Uint64(), uint64(len(forkA)))

	s.RevertL1Snapshot(snapshotID)
	s.L1Mine()
	s.SetHead(l2Head1.Number)
	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(context.Background(), headL1Origin.BlockID)
	s.Nil(err)
	s.d.state.SetL1Current(l1Head)
	s.Nil(s.d.ChainSyncer().Sync())
	s.InitProposer()

	snapshotID = s.SetL1Snapshot()

	for i := 0; i < lenForkB; i++ {
		s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())
	}

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head3.Number.Uint64(), l2Head2.Number.Uint64())

	for i := l2Head1.Number.Uint64() + 1; i <= l2Head3.Number.Uint64(); i++ {
		block, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		s.Nil(err)
		forkB = append(forkB, block)
	}
	s.Equal(l2Head3.Number.Uint64()-l2Head1.Number.Uint64(), uint64(len(forkB)))

	s.RevertL1Snapshot(snapshotID)
	s.L1Mine()
	s.SetHead(l2Head1.Number)
	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(context.Background(), headL1Origin.BlockID)
	s.Nil(err)
	s.d.state.SetL1Current(l1Head)
	s.Nil(s.d.ChainSyncer().Sync())
	s.InitProposer()

	headL1Origin, err = s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64(), headL1Origin.BlockID.Uint64())

	l2Head4, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64(), l2Head4.Number.Uint64())

	// Randomly gossip preconfirmation messages based on the blocks
	// in the forkA and forkB
	blocks := append(forkA, forkB...)
	for i := len(blocks) - 1; i > 0; i-- {
		j := rand.Intn(i + 1)
		blocks[i], blocks[j] = blocks[j], blocks[i]
	}

	for _, block := range blocks {
		baseFee, overflow := uint256.FromBig(block.BaseFee())
		s.False(overflow)

		b, err := utils.EncodeAndCompressTxList(block.Transactions())
		s.Nil(err)
		s.GreaterOrEqual(len(block.Transactions()), 1)

		payload := &eth.ExecutionPayload{
			BlockHash:     block.Hash(),
			ParentHash:    block.ParentHash(),
			FeeRecipient:  block.Coinbase(),
			PrevRandao:    eth.Bytes32(block.MixDigest()),
			BlockNumber:   eth.Uint64Quantity(block.Number().Uint64()),
			GasLimit:      eth.Uint64Quantity(block.GasLimit()),
			Timestamp:     eth.Uint64Quantity(block.Time()),
			ExtraData:     block.Extra(),
			BaseFeePerGas: eth.Uint256Quantity(*baseFee),
			Transactions:  []eth.Data{b},
			Withdrawals:   &types.Withdrawals{},
		}

		s.Nil(s.d.preconfBlockServer.OnUnsafeL2Payload(
			context.Background(),
			peer.ID(testutils.RandomBytes(32)),
			&eth.ExecutionPayloadEnvelope{ExecutionPayload: payload},
		))
	}

	l2Head5, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	// The last block should be the last one in the forkA or forkB
	var isInForkA bool
	for _, b := range forkA {
		if blocks[len(blocks)-1].Hash() == b.Hash() {
			isInForkA = true
			break
		}
	}

	if isInForkA {
		s.Equal(forkA[len(forkA)-1].Number().Uint64(), l2Head5.Number().Uint64())
	} else {
		s.Equal(forkB[len(forkB)-1].Number().Uint64(), l2Head5.Number().Uint64())
	}

	headL1Origin, err = s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64(), headL1Origin.BlockID.Uint64())

	isForkALastBlockCanonical, err := blocksInserter.IsBasedOnCanonicalChain(
		context.Background(),
		s.RPCClient,
		&preconf.Envelope{
			Payload: &eth.ExecutionPayload{
				BlockNumber: eth.Uint64Quantity(forkA[len(forkA)-1].Number().Uint64()),
				BlockHash:   forkA[len(forkA)-1].Hash(),
				ParentHash:  forkA[len(forkA)-1].ParentHash(),
			},
		},
		&rawdb.L1Origin{BlockID: headL1Origin.BlockID, L2BlockHash: testutils.RandomHash()},
	)
	s.Nil(err)

	isForkBLastBlockCanonical, err := blocksInserter.IsBasedOnCanonicalChain(
		context.Background(),
		s.RPCClient,
		&preconf.Envelope{
			Payload: &eth.ExecutionPayload{
				BlockNumber: eth.Uint64Quantity(forkB[len(forkB)-1].Number().Uint64()),
				BlockHash:   forkB[len(forkB)-1].Hash(),
				ParentHash:  forkB[len(forkB)-1].ParentHash(),
			},
		},
		&rawdb.L1Origin{BlockID: headL1Origin.BlockID, L2BlockHash: testutils.RandomHash()},
	)
	s.Nil(err)

	if isInForkA {
		s.True(isForkALastBlockCanonical)
		s.False(isForkBLastBlockCanonical)
	} else {
		s.True(isForkBLastBlockCanonical)
		s.False(isForkALastBlockCanonical)
	}
}

func (s *DriverTestSuite) TestOnUnsafeL2PayloadWithMissingAncients() {
	s.ForkIntoShasta(s.p, s.d.ChainSyncer().EventSyncer())
	// Propose some valid L2 blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())

	l2Head1, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	headL1Origin, err := s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), headL1Origin.BlockID.Uint64())

	snapshotID := s.SetL1Snapshot()

	for i := 0; i < rand.Intn(6)+5; i++ {
		s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())
	}

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number().Uint64())

	blocks := []*types.Block{}
	for i := l2Head1.Number().Uint64() + 1; i <= l2Head2.Number.Uint64(); i++ {
		block, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		s.Nil(err)
		blocks = append(blocks, block)
	}
	s.Equal(l2Head2.Number.Uint64()-l2Head1.Number().Uint64(), uint64(len(blocks)))

	s.RevertL1Snapshot(snapshotID)
	s.SetHead(l2Head1.Number())
	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(context.Background(), headL1Origin.BlockID)
	s.Nil(err)

	headL1Origin, err = s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), headL1Origin.BlockID.Uint64())

	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), l2Head3.Number().Uint64())

	baseFee, overflow := uint256.FromBig(l2Head1.BaseFee())
	s.False(overflow)

	b, err := utils.EncodeAndCompressTxList(l2Head1.Transactions())
	s.Nil(err)
	s.GreaterOrEqual(len(l2Head1.Transactions()), 1)

	s.d.preconfBlockServer.PutPayloadsCache(l2Head1.Number().Uint64(), &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockHash:     l2Head1.Hash(),
			ParentHash:    l2Head1.ParentHash(),
			FeeRecipient:  l2Head1.Coinbase(),
			PrevRandao:    eth.Bytes32(l2Head1.MixDigest()),
			BlockNumber:   eth.Uint64Quantity(l2Head1.Number().Uint64()),
			GasLimit:      eth.Uint64Quantity(l2Head1.GasLimit()),
			Timestamp:     eth.Uint64Quantity(l2Head1.Time()),
			ExtraData:     l2Head1.Extra(),
			BaseFeePerGas: eth.Uint256Quantity(*baseFee),
			Transactions:  []eth.Data{b},
			Withdrawals:   &types.Withdrawals{},
		},
	})

	// Randomly gossip preconfirmation messages with missing ancients
	blockNums := rand.Perm(len(blocks))
	for i := range blockNums {
		blockNums[i] += int(l2Head1.Number().Uint64() + 1)
	}

	getBlock := func(blockNum uint64) *types.Block {
		for _, b := range blocks {
			if b.Number().Uint64() == blockNum {
				return b
			}
		}
		return nil
	}

	insertPayloadFromBlock := func(block *types.Block, gossipRandom bool) {
		baseFee, overflow := uint256.FromBig(block.BaseFee())
		s.False(overflow)

		b, err := utils.EncodeAndCompressTxList(block.Transactions())
		s.Nil(err)
		s.GreaterOrEqual(len(block.Transactions()), 1)

		s.Nil(s.d.preconfBlockServer.OnUnsafeL2Payload(
			context.Background(),
			peer.ID(testutils.RandomBytes(32)),
			&eth.ExecutionPayloadEnvelope{ExecutionPayload: &eth.ExecutionPayload{
				BlockHash:     block.Hash(),
				ParentHash:    block.ParentHash(),
				FeeRecipient:  block.Coinbase(),
				PrevRandao:    eth.Bytes32(block.MixDigest()),
				BlockNumber:   eth.Uint64Quantity(block.Number().Uint64()),
				GasLimit:      eth.Uint64Quantity(block.GasLimit()),
				Timestamp:     eth.Uint64Quantity(block.Time()),
				ExtraData:     block.Extra(),
				BaseFeePerGas: eth.Uint256Quantity(*baseFee),
				Transactions:  []eth.Data{b},
				Withdrawals:   &types.Withdrawals{},
			}},
		))

		if gossipRandom {
			// Also gossip some random blocks
			s.Nil(s.d.preconfBlockServer.OnUnsafeL2Payload(
				context.Background(),
				peer.ID(testutils.RandomBytes(32)),
				&eth.ExecutionPayloadEnvelope{ExecutionPayload: &eth.ExecutionPayload{
					BlockHash:     common.BytesToHash(testutils.RandomBytes(32)),
					ParentHash:    common.BytesToHash(testutils.RandomBytes(32)),
					FeeRecipient:  block.Coinbase(),
					PrevRandao:    eth.Bytes32(common.BytesToHash(testutils.RandomBytes(32))),
					BlockNumber:   eth.Uint64Quantity(block.Number().Uint64()),
					GasLimit:      eth.Uint64Quantity(block.GasLimit()),
					Timestamp:     eth.Uint64Quantity(block.Time()),
					ExtraData:     block.Extra(),
					BaseFeePerGas: eth.Uint256Quantity(*baseFee),
					Transactions:  []eth.Data{b},
					Withdrawals:   &types.Withdrawals{},
				}},
			))

			s.Nil(s.d.preconfBlockServer.OnUnsafeL2Payload(
				context.Background(),
				peer.ID(testutils.RandomBytes(32)),
				&eth.ExecutionPayloadEnvelope{ExecutionPayload: &eth.ExecutionPayload{
					BlockHash:     common.BytesToHash(testutils.RandomBytes(32)),
					ParentHash:    block.ParentHash(),
					FeeRecipient:  block.Coinbase(),
					PrevRandao:    eth.Bytes32(common.BytesToHash(testutils.RandomBytes(32))),
					BlockNumber:   eth.Uint64Quantity(block.Number().Uint64()),
					GasLimit:      eth.Uint64Quantity(block.GasLimit()),
					Timestamp:     eth.Uint64Quantity(block.Time()),
					ExtraData:     block.Extra(),
					BaseFeePerGas: eth.Uint256Quantity(*baseFee),
					Transactions:  []eth.Data{b},
					Withdrawals:   &types.Withdrawals{},
				}},
			))
		}
	}

	// Insert all blocks except the first one
	for _, blockNum := range blockNums {
		if blockNum <= int(l2Head1.Number().Uint64()+2) {
			continue
		}

		block := getBlock(uint64(blockNum))
		s.NotNil(block)

		insertPayloadFromBlock(block, true)
	}

	l2Head4, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), l2Head4.Number().Uint64())

	// Insert the only two missing ancient blocks
	block := getBlock(l2Head1.Number().Uint64() + 1)
	s.NotNil(block)
	baseFee, overflow = uint256.FromBig(block.BaseFee())
	s.False(overflow)

	b, err = utils.EncodeAndCompressTxList(block.Transactions())
	s.Nil(err)
	s.GreaterOrEqual(len(block.Transactions()), 1)

	s.d.preconfBlockServer.PutPayloadsCache(block.Number().Uint64(), &preconf.Envelope{
		Payload: &eth.ExecutionPayload{
			BlockHash:     block.Hash(),
			ParentHash:    block.ParentHash(),
			FeeRecipient:  block.Coinbase(),
			PrevRandao:    eth.Bytes32(block.MixDigest()),
			BlockNumber:   eth.Uint64Quantity(block.Number().Uint64()),
			GasLimit:      eth.Uint64Quantity(block.GasLimit()),
			Timestamp:     eth.Uint64Quantity(block.Time()),
			ExtraData:     block.Extra(),
			BaseFeePerGas: eth.Uint256Quantity(*baseFee),
			Transactions:  []eth.Data{b},
			Withdrawals:   &types.Withdrawals{},
		},
	})

	block = getBlock(l2Head1.Number().Uint64() + 2)
	s.NotNil(block)
	insertPayloadFromBlock(block, false)

	l2Head5, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number.Uint64(), l2Head5.Number().Uint64())
}

func (s *DriverTestSuite) TestSyncerImportPendingBlocksFromCache() {
	s.ForkIntoShasta(s.p, s.d.l2ChainSyncer.EventSyncer())
	// Propose some valid L2 blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())

	l2Head1, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	headL1Origin, err := s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), headL1Origin.BlockID.Uint64())

	snapshotID := s.SetL1Snapshot()

	for i := 0; i < rand.Intn(3)+2; i++ {
		s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().EventSyncer())
	}

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number().Uint64())

	for i := l2Head1.Number().Uint64() + 1; i <= l2Head2.Number.Uint64(); i++ {
		block, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		s.Nil(err)

		log.Info("Put payloads cache for block", "number", block.Number().Uint64(), "hash", block.Hash().Hex())

		baseFee, overflow := uint256.FromBig(block.BaseFee())
		s.False(overflow)

		b, err := utils.EncodeAndCompressTxList(block.Transactions())
		s.Nil(err)
		s.GreaterOrEqual(len(block.Transactions()), 1)

		s.d.preconfBlockServer.PutPayloadsCache(block.Number().Uint64(), &preconf.Envelope{
			Payload: &eth.ExecutionPayload{
				BlockHash:     block.Hash(),
				ParentHash:    block.ParentHash(),
				FeeRecipient:  block.Coinbase(),
				PrevRandao:    eth.Bytes32(block.MixDigest()),
				BlockNumber:   eth.Uint64Quantity(block.Number().Uint64()),
				GasLimit:      eth.Uint64Quantity(block.GasLimit()),
				Timestamp:     eth.Uint64Quantity(block.Time()),
				ExtraData:     block.Extra(),
				BaseFeePerGas: eth.Uint256Quantity(*baseFee),
				Transactions:  []eth.Data{b},
				Withdrawals:   &types.Withdrawals{},
			},
		})
	}

	s.RevertL1Snapshot(snapshotID)
	s.SetHead(l2Head1.Number())
	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(context.Background(), headL1Origin.BlockID)
	s.Nil(err)

	headL1Origin, err = s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), headL1Origin.BlockID.Uint64())

	s.Nil(s.d.ChainSyncer().SetUpEventSync(headL1Origin.BlockID.Uint64()))

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	// SetUpEventSync no longer imports cached preconf blocks; ensure head stays at the reverted point.
	s.Equal(l2Head1.Number().Uint64(), l2Head3.Number.Uint64())
	s.Equal(l2Head1.Hash(), l2Head3.Hash())

	// Simulate the first post-beacon event sync enabling preconf imports.
	s.d.preconfBlockServer.SetSyncReady(true)
	s.Nil(s.d.preconfBlockServer.ImportPendingBlocksFromCache(context.Background()))

	l2Head4, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number.Uint64(), l2Head4.Number.Uint64())
	s.Equal(l2Head2.Hash(), l2Head4.Hash())

	headL1Origin, err = s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head1.Number().Uint64(), headL1Origin.BlockID.Uint64())
}

func (s *DriverTestSuite) proposePreconfBatch(
	blocks []*types.Block,
	anchoredL1Blocks []*types.Header,
	timeShifts []uint8,
) {
	var (
		to          = &s.p.PacayaInboxAddress
		proposer    = crypto.PubkeyToAddress(s.p.L1ProposerPrivKey.PublicKey)
		data        []byte
		blockParams []pacayaBindings.ITaikoInboxBlockParams
		allTxs      types.Transactions
	)

	if s.p.ProverSetAddress != rpc.ZeroAddress {
		to = &s.p.ProverSetAddress
		proposer = s.p.ProverSetAddress
	}

	s.NotZero(len(blocks))
	s.Equal(len(blocks), len(anchoredL1Blocks))
	s.Equal(len(blocks), len(timeShifts))

	for i, b := range blocks {
		allTxs = append(allTxs, b.Transactions()[1:]...)
		blockParams = append(blockParams, pacayaBindings.ITaikoInboxBlockParams{
			NumTransactions: uint16(b.Transactions()[1:].Len()),
			TimeShift:       timeShifts[i],
		})
	}

	rlpEncoded, err := rlp.EncodeToBytes(allTxs)
	s.Nil(err)
	txListsBytes, err := utils.Compress(rlpEncoded)
	s.Nil(err)

	encodedParams, err := encoding.EncodeBatchParamsWithForcedInclusion(
		nil,
		&encoding.BatchParams{
			Proposer: proposer,
			Coinbase: blocks[0].Coinbase(),
			BlobParams: encoding.BlobParams{
				ByteOffset: 0,
				ByteSize:   uint32(len(txListsBytes)),
			},
			Blocks:             blockParams,
			AnchorBlockId:      anchoredL1Blocks[0].Number.Uint64(),
			LastBlockTimestamp: blocks[len(blocks)-1].Time(),
		})
	s.Nil(err)

	if s.p.ProverSetAddress != rpc.ZeroAddress {
		data, err = encoding.ProverSetPacayaABI.Pack("proposeBatch", encodedParams, txListsBytes)
	} else {
		data, err = encoding.TaikoInboxABI.Pack("proposeBatch", encodedParams, txListsBytes)
	}
	s.Nil(err)
	s.Nil(s.p.SendTx(context.Background(), &txmgr.TxCandidate{TxData: data, Blobs: nil, To: to}))
	s.Nil(
		backoff.Retry(func() error {
			return s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background())
		}, backoff.NewExponentialBackOff()))
}

func (s *DriverTestSuite) InitProposer() {
	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		p                 = new(proposer.Proposer)
	)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	s.Nil(p.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  os.Getenv("L1_WS"),
			L2Endpoint:                  os.Getenv("L2_WS"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
			ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:         1024 * time.Hour,
		MaxTxListsPerEpoch:      1,
		BlobAllowed:             true,
		TxmgrConfigs: &txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(l1ProposerPrivKey)),
			FeeLimitMultiplier:        txmgr.DefaultBatcherFlagValues.FeeLimitMultiplier,
			FeeLimitThresholdGwei:     txmgr.DefaultBatcherFlagValues.FeeLimitThresholdGwei,
			MinBaseFeeGwei:            txmgr.DefaultBatcherFlagValues.MinBaseFeeGwei,
			MinTipCapGwei:             txmgr.DefaultBatcherFlagValues.MinTipCapGwei,
			ResubmissionTimeout:       txmgr.DefaultBatcherFlagValues.ResubmissionTimeout,
			ReceiptQueryInterval:      1 * time.Second,
			NetworkTimeout:            txmgr.DefaultBatcherFlagValues.NetworkTimeout,
			TxSendTimeout:             txmgr.DefaultBatcherFlagValues.TxSendTimeout,
			TxNotInMempoolTimeout:     txmgr.DefaultBatcherFlagValues.TxNotInMempoolTimeout,
		},
		PrivateTxmgrConfigs: &txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(l1ProposerPrivKey)),
			FeeLimitMultiplier:        txmgr.DefaultBatcherFlagValues.FeeLimitMultiplier,
			FeeLimitThresholdGwei:     txmgr.DefaultBatcherFlagValues.FeeLimitThresholdGwei,
			MinBaseFeeGwei:            txmgr.DefaultBatcherFlagValues.MinBaseFeeGwei,
			MinTipCapGwei:             txmgr.DefaultBatcherFlagValues.MinTipCapGwei,
			ResubmissionTimeout:       txmgr.DefaultBatcherFlagValues.ResubmissionTimeout,
			ReceiptQueryInterval:      1 * time.Second,
			NetworkTimeout:            txmgr.DefaultBatcherFlagValues.NetworkTimeout,
			TxSendTimeout:             txmgr.DefaultBatcherFlagValues.TxSendTimeout,
			TxNotInMempoolTimeout:     txmgr.DefaultBatcherFlagValues.TxNotInMempoolTimeout,
		},
	}, nil, nil))
	s.p = p
	s.p.RegisterTxMgrSelectorToBlobServer(s.BlobServer)
}

func TestDriverTestSuite(t *testing.T) {
	suite.Run(t, new(DriverTestSuite))
}

// insertPreconfBlock inserts a preconfirmation block with the given parameters.
func (s *DriverTestSuite) insertPreconfBlock(
	url *url.URL,
	anchoredL1Block *types.Header,
	l2BlockID uint64,
	timestamp uint64,
) *resty.Response {
	preconferPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	preconferAddress := crypto.PubkeyToAddress(preconferPrivKey.PublicKey)

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(testutils.RandomBytes(32)),
		common.Big0,
		100_000,
		new(big.Int).SetUint64(uint64(10*params.GWei)),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)

	// If the transaction is underpriced, we just ignore it.
	err = s.RPCClient.L2.SendTransaction(context.Background(), signedTx)
	if err != nil {
		s.Equal("replacement transaction underpriced", err.Error())
	}

	parent, err := s.d.rpc.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(l2BlockID-1))
	s.Nil(err)

	l1Head, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	var baseFee *big.Int
	if l1Head.Time >= s.RPCClient.ShastaClients.ForkTime {
		baseFee, err = s.RPCClient.CalculateBaseFeeShasta(context.Background(), parent)
		s.Nil(err)
	} else {
		baseFee, err = s.RPCClient.CalculateBaseFeePacaya(
			context.Background(), parent, timestamp, s.d.protocolConfig.BaseFeeConfig(),
		)
		s.Nil(err)
	}

	anchortxConstructor, err := anchortxconstructor.New(s.d.rpc)
	s.Nil(err)

	anchorTx, err := anchortxConstructor.AssembleAnchorV3Tx(
		context.Background(),
		anchoredL1Block.Number,
		anchoredL1Block.Root,
		parent,
		s.d.protocolConfig.BaseFeeConfig(),
		[][32]byte{},
		new(big.Int).Add(parent.Number, common.Big1),
		baseFee,
	)
	s.Nil(err)

	b, err := utils.EncodeAndCompressTxList(types.Transactions{anchorTx, signedTx})
	s.Nil(err)

	extraData := encoding.EncodeBaseFeeConfig(s.d.protocolConfig.BaseFeeConfig())
	s.NotEmpty(extraData)

	reqBody := &preconfblocks.BuildPreconfBlockRequestBody{
		ExecutableData: &preconfblocks.ExecutableData{
			ParentHash:    parent.Hash(),
			FeeRecipient:  preconferAddress,
			Number:        l2BlockID,
			GasLimit:      uint64(s.d.protocolConfig.BlockMaxGasLimit() + uint32(consensus.AnchorV3V4GasLimit)),
			ExtraData:     hexutil.Bytes(extraData[:]),
			Timestamp:     timestamp,
			Transactions:  b,
			BaseFeePerGas: baseFee.Uint64(),
		},
	}

	payload, err := rlp.EncodeToBytes(reqBody)
	s.Nil(err)
	s.NotEmpty(payload)

	// Try to propose a preconfirmation block
	res, err := resty.New().
		R().
		SetBody(reqBody).
		Post(url.String() + "/preconfBlocks")
	s.Nil(err)
	log.Info("Preconfirmation block creation response", "body", res.String())
	return res
}
