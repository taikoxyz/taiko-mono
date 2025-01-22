package blob

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"os"
	"testing"
	"time"

	"golang.org/x/exp/slog"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
)

type BlobSyncerTestSuite struct {
	testutils.ClientTestSuite
	s         *Syncer
	p         testutils.Proposer
	eventChan chan *bindings.TaikoL1ClientBlockProposed
}

func (s *BlobSyncerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	state2, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)

	s.eventChan = make(chan *bindings.TaikoL1ClientBlockProposed, 200)

	syncer, err := NewSyncer(
		context.Background(),
		s.RPCClient,
		state2,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 1*time.Hour),
		0,
		nil,
		nil,
	)
	s.Nil(err)
	s.s = syncer

	s.initProposer()
}

func (s *BlobSyncerTestSuite) TestProcessL1Blocks() {
	s.Nil(s.s.ProcessL1Blocks(context.Background()))
}

func (s *BlobSyncerTestSuite) TestProcessL1BlocksReorg() {
	s.ProposeAndInsertEmptyBlocks(s.p, s.s)
	s.Nil(s.s.ProcessL1Blocks(context.Background()))
}

func (s *BlobSyncerTestSuite) TestOnBlockProposed() {
	s.Nil(s.s.onBlockProposed(
		context.Background(),
		&metadata.TaikoDataBlockMetadataOntake{TaikoDataBlockMetadataV2: bindings.TaikoDataBlockMetadataV2{Id: 0}},
		func() {},
	))
	s.NotNil(s.s.onBlockProposed(
		context.Background(),
		&metadata.TaikoDataBlockMetadataOntake{TaikoDataBlockMetadataV2: bindings.TaikoDataBlockMetadataV2{Id: 1}},
		func() {},
	))
}

func (s *BlobSyncerTestSuite) TestInsertNewHead() {
	parent, err := s.s.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l1Head, err := s.s.rpc.L1.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	protocolConfigs, err := s.s.rpc.TaikoL1.GetConfig(nil)
	s.Nil(err)
	_, err = s.s.insertNewHead(
		context.Background(),
		&metadata.TaikoDataBlockMetadataOntake{
			TaikoDataBlockMetadataV2: bindings.TaikoDataBlockMetadataV2{
				Id:              1,
				AnchorBlockId:   l1Head.NumberU64(),
				AnchorBlockHash: l1Head.Hash(),
				Coinbase:        common.BytesToAddress(testutils.RandomBytes(1024)),
				BlobHash:        testutils.RandomHash(),
				Difficulty:      testutils.RandomHash(),
				GasLimit:        utils.RandUint32(nil),
				Timestamp:       uint64(time.Now().Unix()),
				BaseFeeConfig:   protocolConfigs.BaseFeeConfig,
			},
			Log: types.Log{
				BlockNumber: l1Head.Number().Uint64(),
				BlockHash:   l1Head.Hash(),
			},
		},
		parent,
		[]byte{},
		&rawdb.L1Origin{
			BlockID:       common.Big1,
			L1BlockHeight: common.Big1,
			L1BlockHash:   testutils.RandomHash(),
		},
	)
	s.Nil(err)
}

func (s *BlobSyncerTestSuite) TestInsertNewHeadUsingDecodedTxList() {
	parent, err := s.s.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l1Head, err := s.s.rpc.L1.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	txList := []*types.Transaction{
		types.NewTransaction(0, common.BytesToAddress(testutils.RandomBytes(20)), big.NewInt(0), 21000, big.NewInt(1), nil),
	}
	err = s.s.insertNewHeadUsingDecodedTxList(
		context.Background(),
		parent,
		common.Big1,
		txList,
		&rawdb.L1Origin{
			BlockID:       common.Big1,
			L1BlockHeight: common.Big1,
			L1BlockHash:   l1Head.Hash(),
		},
	)
	s.Nil(err)
}

func (s *BlobSyncerTestSuite) TestMoveTheHead() {
	parent, err := s.s.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Create a new transaction
	tx := types.NewTransaction(
		0,
		common.BytesToAddress(testutils.RandomBytes(20)),
		big.NewInt(0),
		21000,
		big.NewInt(1),
		nil,
	)

	// Sign the transaction
	privateKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)
	signedTx, err := s.signTransaction(tx, privateKey)
	s.Nil(err)

	txList := []*types.Transaction{signedTx}

	err = s.s.MoveTheHead(
		context.Background(),
		txList,
	)
	s.Nil(err)

	// Verify that the head has moved by checking the latest block header
	newParent, err := s.s.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newParent.Number.Uint64(), parent.Number.Uint64())

	// Verify that the transactions were included in the new head block
	block, err := s.s.rpc.L2.BlockByHash(context.Background(), newParent.Hash())
	s.Nil(err)
	_ = block
	slog.Debug(
		"New head block",
		"number", newParent.Number,
		"hash", newParent.Hash(),
		"transactions", block.Transactions(),
	)

	s.Equal(len(txList)+1, len(block.Transactions())) // anchor tx
	for i, tx := range txList {
		s.Equal(tx.Hash(), block.Transactions()[i+1].Hash()) // i+1 because anchor tx is the first tx
	}
}

func (s *BlobSyncerTestSuite) signTransaction(
	tx *types.Transaction,
	privateKey *ecdsa.PrivateKey,
) (*types.Transaction, error) {
	chainID, err := s.FetchChainID()
	if err != nil {
		return nil, err
	}
	signer := types.NewEIP155Signer(chainID)
	signedTx, err := types.SignTx(tx, signer, privateKey)
	if err != nil {
		return nil, err
	}
	return signedTx, nil
}

// FetchChainID fetches the chain ID from the Ethereum client.
func (s *BlobSyncerTestSuite) FetchChainID() (*big.Int, error) {
	var chainID string
	err := s.RPCClient.L2.CallContext(context.Background(), &chainID, "eth_chainId")
	if err != nil {
		return nil, err
	}
	id := new(big.Int)
	id.SetString(chainID[2:], 16) // Convert hex string to big.Int
	slog.Info("Chain ID", "id", id)
	return id, nil
}

func (s *BlobSyncerTestSuite) TestTreasuryIncomeAllAnchors() {
	// TODO: Temporarily skip this test case when using l2_reth node.
	if os.Getenv("L2_NODE") == "l2_reth" {
		s.T().Skip()
	}
	treasury := common.HexToAddress(os.Getenv("TREASURY"))
	s.NotZero(treasury.Big().Uint64())

	balance, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	headBefore, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	s.ProposeAndInsertEmptyBlocks(s.p, s.s)

	headAfter, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	balanceAfter, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	s.Greater(headAfter, headBefore)
	s.Equal(1, balanceAfter.Cmp(balance))
}

func (s *BlobSyncerTestSuite) TestTreasuryIncome() {
	// TODO: Temporarily skip this test case when using l2_reth node.
	if os.Getenv("L2_NODE") == "l2_reth" {
		s.T().Skip()
	}
	treasury := common.HexToAddress(os.Getenv("TREASURY"))
	s.NotZero(treasury.Big().Uint64())

	balance, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	headBefore, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	s.ProposeAndInsertEmptyBlocks(s.p, s.s)
	s.ProposeAndInsertValidBlock(s.p, s.s)

	headAfter, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	balanceAfter, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	s.Greater(headAfter, headBefore)
	s.True(balanceAfter.Cmp(balance) > 0)

	protocolConfigs, err := rpc.GetProtocolConfigs(s.RPCClient.TaikoL1, nil)
	s.Nil(err)

	var hasNoneAnchorTxs bool
	chainConfig := config.NewChainConfig(&protocolConfigs)
	for i := headBefore + 1; i <= headAfter; i++ {
		block, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		s.Nil(err)
		s.GreaterOrEqual(block.Transactions().Len(), 1)
		s.Greater(block.BaseFee().Uint64(), uint64(0))

		for j, tx := range block.Transactions() {
			if j == 0 {
				continue
			}

			hasNoneAnchorTxs = true
			receipt, err := s.RPCClient.L2.TransactionReceipt(context.Background(), tx.Hash())
			s.Nil(err)

			fee := new(big.Int).Mul(block.BaseFee(), new(big.Int).SetUint64(receipt.GasUsed))
			if chainConfig.IsOntake(block.Number()) {
				feeCoinbase := new(big.Int).Div(
					new(big.Int).Mul(fee, new(big.Int).SetUint64(uint64(chainConfig.ProtocolConfigs.BaseFeeConfig.SharingPctg))),
					new(big.Int).SetUint64(100),
				)
				feeTreasury := new(big.Int).Sub(fee, feeCoinbase)
				balance = new(big.Int).Add(balance, feeTreasury)
			} else {
				balance = new(big.Int).Add(balance, fee)
			}
		}
	}

	s.True(hasNoneAnchorTxs)
	s.Zero(balanceAfter.Cmp(balance))
}

func (s *BlobSyncerTestSuite) initProposer() {
	prop := new(proposer.Proposer)
	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	s.Nil(prop.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        os.Getenv("L1_WS"),
			L2Endpoint:        os.Getenv("L2_WS"),
			L2EngineEndpoint:  os.Getenv("L2_AUTH"),
			JwtSecret:         string(jwtSecret),
			TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1")),
			TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2")),
			TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:            1024 * time.Hour,
		MaxProposedTxListsPerEpoch: 1,
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

	s.p = prop
}

func TestBlobSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(BlobSyncerTestSuite))
}
