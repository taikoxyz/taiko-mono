package driver

import (
	"context"
	"fmt"
	"math/big"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
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
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	anchortxconstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	preconfblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
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
			L1Endpoint:       os.Getenv("L1_WS"),
			L2Endpoint:       os.Getenv("L2_WS"),
			L2EngineEndpoint: os.Getenv("L2_AUTH"),
			TaikoL1Address:   common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			TaikoL2Address:   common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			JwtSecret:        string(jwtSecret),
		},
		BlobServerEndpoint:     s.BlobServer.URL(),
		P2PConfigs:             p2pConfig,
		P2PSignerConfigs:       p2pSignerConfig,
		PreconfBlockServerPort: preconfServerPort,
	}))
	s.d = d
	s.cancel = cancel

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

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	// Propose a valid L2 block
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	// Empty blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().BlobSyncer())
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
		if err != nil {
			method, err = encoding.TaikoL2ABI.MethodById(anchorTx.Data())
		}
		s.Nil(err)
		s.Contains(method.Name, "anchor")
	}
}

func (s *DriverTestSuite) TestCheckL1ReorgToHigherFork() {
	if os.Getenv("L2_NODE") == "l2_reth" {
		s.T().Skip()
	}
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		l2Head2.Number,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	// Because of evm_revert operation, the nonce of the proposer need to be adjusted.
	// Propose ten blocks on another fork
	for i := 0; i < 10; i++ {
		s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
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
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
	time.Sleep(3 * time.Second)
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		l2Head2.Number,
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

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	parent, err := s.d.rpc.L2.HeaderByHash(context.Background(), l2Head3.ParentHash)
	s.Nil(err)
	s.Equal(l2Head3.Number.Uint64(), l2Head2.Number.Uint64()-1)
	s.Equal(parent.Hash(), l2Head1.Hash())
}

func (s *DriverTestSuite) TestCheckL1ReorgToSameHeightFork() {
	s.T().Skip("Skip this test case because of the anvil timestamp issue after rollback.")
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
	time.Sleep(3 * time.Second)
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		l2Head2.Number,
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

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

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
	s.ForkIntoPacaya(s.p, s.d.ChainSyncer().BlobSyncer())

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	forcedInclusionTx, err := testutils.AssembleTestTx(
		s.RPCClient.L2,
		s.TestAddrPrivKey,
		nonce,
		&s.TestAddr,
		common.Big0,
		[]byte{},
	)
	s.Nil(err)
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
	s.Nil(s.d.l2ChainSyncer.BlobSyncer().ProcessL1Blocks(context.Background()))

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
	s.Nil(s.d.l2ChainSyncer.BlobSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64()+1, l2Head3.Number().Uint64())
	s.Equal(1, len(l2Head3.Transactions()))
}

func (s *DriverTestSuite) TestL1Current() {
	// propose and insert a block
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().BlobSyncer())
	// reset L1 current with increased height
	s.Nil(s.d.state.ResetL1Current(s.d.ctx, common.Big1))
}

func (s *DriverTestSuite) TestInsertPreconfBlocks() {
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	// Propose valid L2 blocks to make the L2 fork into Pacaya fork.
	s.ForkIntoPacaya(s.p, s.d.ChainSyncer().BlobSyncer())

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	res, err := resty.New().R().Get(s.preconfServerURL.String() + "/healthz")
	s.Nil(err)
	s.True(res.IsSuccess())

	// Try to insert two preconfirmation blocks
	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head2.Number.Uint64()+1).IsSuccess())
	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(2, len(l2Head3.Transactions()))

	l1Origin, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head2.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64(), l1Origin.BlockID.Uint64())
	s.Equal(l2Head3.Hash(), l1Origin.L2BlockHash)
	s.Equal(common.Hash{}, l1Origin.L1BlockHash)
	s.True(l1Origin.IsPreconfBlock())

	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head2.Number.Uint64()+2).IsSuccess())
	l2Head4, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(2, len(l2Head4.Transactions()))

	l1Origin2, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head2.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64(), l1Origin2.BlockID.Uint64())
	s.Equal(l2Head3.Hash(), l1Origin2.L2BlockHash)
	s.Equal(common.Hash{}, l1Origin2.L1BlockHash)
	s.True(l1Origin2.IsPreconfBlock())

	// Remove one preconf block
	res, err = resty.New().
		R().
		SetBody(&preconfblocks.RemovePreconfBlocksRequestBody{
			NewLastBlockID: l2Head4.Number().Uint64() - 1,
		}).
		Delete(s.preconfServerURL.String() + "/preconfBlocks")
	s.Nil(err)
	s.True(res.IsSuccess())

	l2Head5, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head3.Hash(), l2Head5.Hash())

	canonicalL1Origin, err := s.RPCClient.L2.HeadL1Origin(context.Background())
	s.Nil(err)
	s.Equal(l2Head2.Number.Uint64(), canonicalL1Origin.BlockID.Uint64())
	s.False(canonicalL1Origin.IsPreconfBlock())

	// Propose 3 valid L2 blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().BlobSyncer())

	l2Head6, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64()+2, l2Head6.Number().Uint64())
	s.Equal(1, len(l2Head6.Transactions()))

	l1Origin3, err := s.RPCClient.L2.L1OriginByID(context.Background(), l2Head6.Number())
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64()+2, l1Origin3.BlockID.Uint64())
	s.Equal(l2Head6.Hash(), l1Origin3.L2BlockHash)
	s.NotZero(l1Origin3.L1BlockHeight.Uint64())
	s.NotEmpty(l1Origin3.L1BlockHash)
	s.False(l1Origin3.IsPreconfBlock())
}

func (s *DriverTestSuite) TestInsertPreconfBlocksNotReorg() {
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	// Propose valid L2 blocks to make the L2 fork into Pacaya fork.
	s.ForkIntoPacaya(s.p, s.d.ChainSyncer().BlobSyncer())

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	res, err := resty.New().R().Get(s.preconfServerURL.String() + "/healthz")
	s.Nil(err)
	s.True(res.IsSuccess())

	// Try to insert one preconfirmation block
	s.True(s.insertPreconfBlock(s.preconfServerURL, l1Head1, l2Head2.Number.Uint64()+1).IsSuccess())
	l2Head3, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(2, len(l2Head3.Transactions()))

	l1Origin, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head2.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64(), l1Origin.BlockID.Uint64())
	s.Equal(l2Head3.Hash(), l1Origin.L2BlockHash)
	s.Equal(common.Hash{}, l1Origin.L1BlockHash)
	s.True(l1Origin.IsPreconfBlock())

	// Propose a same L2 block batch
	s.proposePreconfBatch([]*types.Block{l2Head3}, []*types.Header{l1Head1})

	l2Head4, err := s.d.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head3.Number().Uint64(), l2Head4.Number().Uint64())
	s.Equal(2, len(l2Head4.Transactions()))

	l1Origin2, err := s.RPCClient.L2.L1OriginByID(context.Background(), new(big.Int).Add(l2Head2.Number, common.Big1))
	s.Nil(err)
	s.Equal(l2Head4.Number().Uint64(), l1Origin2.BlockID.Uint64())
	s.Equal(l2Head4.Hash(), l1Origin2.L2BlockHash)
	s.Equal(l2Head3.Hash(), l1Origin2.L2BlockHash)
	s.NotEqual(common.Hash{}, l1Origin2.L1BlockHash)
	s.False(l1Origin2.IsPreconfBlock())
}

func (s *DriverTestSuite) TestOnUnsafeL2Payload() {
	s.ForkIntoPacaya(s.p, s.d.ChainSyncer().BlobSyncer())
	// Propose some valid L2 blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().BlobSyncer())

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
		l2Head1.GasUsed,
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

	// failed to decode txList: rlp: expected input list for types.Transactions
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

func (s *DriverTestSuite) proposePreconfBatch(blocks []*types.Block, anchoredL1Blocks []*types.Header) {
	var (
		to          = &s.p.TaikoL1Address
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

	for _, b := range blocks {
		allTxs = append(allTxs, b.Transactions()[1:]...)
		blockParams = append(blockParams, pacayaBindings.ITaikoInboxBlockParams{
			NumTransactions: uint16(b.Transactions()[1:].Len()),
			TimeShift:       0,
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
			return s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background())
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
			TaikoL1Address:              common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			TaikoL2Address:              common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:            1024 * time.Hour,
		MaxProposedTxListsPerEpoch: 1,
		BlobAllowed:                true,
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
	s.p.RegisterTxMgrSelctorToBlobServer(s.BlobServer)
}

func (s *DriverTestSuite) TearDownTestTearDown() {
	if s.d.preconfBlockServer != nil {
		s.NotNil(s.d.preconfBlockServer.Shutdown(context.Background()))
	}
}

func TestDriverTestSuite(t *testing.T) {
	suite.Run(t, new(DriverTestSuite))
}

// insertPreconfBlock inserts a preconfirmation block with the given parameters.
func (s *DriverTestSuite) insertPreconfBlock(
	url *url.URL,
	anchoredL1Block *types.Header,
	l2BlockID uint64,
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

	// If the transaction is underpriced, we just ingore it.
	err = s.RPCClient.L2.SendTransaction(context.Background(), signedTx)
	if err != nil {
		s.Equal("replacement transaction underpriced", err.Error())
	}

	parent, err := s.d.rpc.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(l2BlockID-1))
	s.Nil(err)

	baseFee, err := s.RPCClient.CalculateBaseFee(
		context.Background(),
		parent,
		true,
		s.d.protocolConfig.BaseFeeConfig(),
		anchoredL1Block.Time,
	)
	s.Nil(err)

	anchortxConstructor, err := anchortxconstructor.New(s.d.rpc)
	s.Nil(err)

	anchorTx, err := anchortxConstructor.AssembleAnchorV3Tx(
		context.Background(),
		anchoredL1Block.Number,
		anchoredL1Block.Root,
		parent.GasUsed,
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
			GasLimit:      uint64(s.d.protocolConfig.BlockMaxGasLimit() + uint32(consensus.AnchorV3GasLimit)),
			ExtraData:     hexutil.Bytes(extraData[:]),
			Timestamp:     anchoredL1Block.Time,
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
