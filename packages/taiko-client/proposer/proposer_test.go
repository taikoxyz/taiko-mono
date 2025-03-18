package proposer

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"maps"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/blob"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type ProposerTestSuite struct {
	testutils.ClientTestSuite
	s      *blob.Syncer
	p      *Proposer
	cancel context.CancelFunc
}

func (s *ProposerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	state2, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)

	syncer, err := blob.NewSyncer(
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

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	p := new(Proposer)

	ctx, cancel := context.WithCancel(context.Background())
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	s.Nil(p.InitFromConfig(ctx, &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        os.Getenv("L1_WS"),
			L2Endpoint:        os.Getenv("L2_HTTP"),
			L2EngineEndpoint:  os.Getenv("L2_AUTH"),
			JwtSecret:         string(jwtSecret),
			TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1")),
			TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2")),
			TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		MinProposingInternal:       0,
		ProposeInterval:            1024 * time.Hour,
		MaxProposedTxListsPerEpoch: 1,
		ProposeBlockTxGasLimit:     10_000_000,
		FallbackToCalldata:         true,
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
	s.cancel = cancel
}

func (s *ProposerTestSuite) TestTxPoolContentWithMinTip() {
	if os.Getenv("L2_NODE") == "l2_reth" {
		s.T().Skip()
	}

	// Empty mempool at first.
	for {
		poolContent, err := s.RPCClient.GetPoolContent(
			context.Background(),
			s.p.proposerAddress,
			s.p.protocolConfigs.BlockMaxGasLimit,
			rpc.BlockMaxTxListBytes,
			s.p.LocalAddresses,
			10,
			0,
			s.p.chainConfig,
		)
		s.Nil(err)

		if len(poolContent) > 0 {
			s.Nil(s.p.ProposeOp(context.Background()))
			s.Nil(s.s.ProcessL1Blocks(context.Background()))
			continue
		}
		break
	}

	privetKeyHexList := []string{
		"0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", // 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
		"0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a", // 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
		"0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6", // 0x90F79bf6EB2c4f870365E785982E1f101E93b906
		"0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a", // 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
		"0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba", // 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
	}

	var privateKeys []*ecdsa.PrivateKey
	for _, privateKeyHex := range privetKeyHexList {
		priv, err := crypto.ToECDSA(common.FromHex(privateKeyHex))
		s.Nil(err)
		privateKeys = append(privateKeys, priv)
	}

	originalNonceMap := make(map[common.Address]uint64)
	for _, priv := range privateKeys {
		transactOpts, err := bind.NewKeyedTransactorWithChainID(priv, s.RPCClient.L2.ChainID)
		s.Nil(err)
		nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), transactOpts.From)
		s.Nil(err)
		originalNonceMap[transactOpts.From] = nonce
		// Send 1500 transactions to mempool
		for i := 0; i < 300; i++ {
			_, err = testutils.AssembleTestTx(s.RPCClient.L2, priv, nonce+uint64(i), &transactOpts.From, common.Big1, nil)
			s.Nil(err)
		}
	}

	for _, testCase := range []struct {
		blockMaxGasLimit     uint32
		blockMaxTxListBytes  uint64
		maxTransactionsLists uint64
		txLengthList         []int
	}{
		{
			s.p.protocolConfigs.BlockMaxGasLimit,
			rpc.BlockMaxTxListBytes,
			s.p.MaxProposedTxListsPerEpoch,
			[]int{1500},
		},
		{
			s.p.protocolConfigs.BlockMaxGasLimit,
			rpc.BlockMaxTxListBytes,
			s.p.MaxProposedTxListsPerEpoch * 5,
			[]int{1500},
		},
		{
			s.p.protocolConfigs.BlockMaxGasLimit / 50,
			rpc.BlockMaxTxListBytes,
			200,
			[]int{129, 129, 129, 129, 129, 129, 129, 129, 129, 129, 129, 81},
		},
	} {
		poolContent, err := s.RPCClient.GetPoolContent(
			context.Background(),
			s.p.proposerAddress,
			testCase.blockMaxGasLimit,
			testCase.blockMaxTxListBytes,
			s.p.LocalAddresses,
			testCase.maxTransactionsLists,
			0,
			s.p.chainConfig,
		)
		s.Nil(err)

		nonceMap := maps.Clone(originalNonceMap)
		// Check the order of nonce.
		for _, txList := range poolContent {
			for _, tx := range txList.TxList {
				sender, err := types.Sender(types.LatestSignerForChainID(s.RPCClient.L2.ChainID), tx)
				s.Nil(err)
				s.Equalf(nonceMap[sender], tx.Nonce(),
					fmt.Sprintf("incorrect nonce of %s, expect: %d, actual: %d",
						sender.String(),
						nonceMap[sender],
						tx.Nonce(),
					))
				nonceMap[sender]++
			}
		}

		s.GreaterOrEqual(int(testCase.maxTransactionsLists), len(poolContent))
		for i, txsLen := range testCase.txLengthList {
			s.Equal(txsLen, poolContent[i].TxList.Len())
			s.GreaterOrEqual(uint64(testCase.blockMaxGasLimit), poolContent[i].EstimatedGasUsed)
			s.GreaterOrEqual(testCase.blockMaxTxListBytes, poolContent[i].BytesLength)
		}
	}

	s.Nil(s.p.ProposeOp(context.Background()))
	s.Nil(s.s.ProcessL1Blocks(context.Background()))
}

func (s *ProposerTestSuite) TestProposeOpNoEmptyBlock() {
	// TODO: Temporarily skip this test case when using l2_reth node.
	if os.Getenv("L2_NODE") == "l2_reth" {
		s.T().Skip()
	}
	defer s.Nil(s.s.ProcessL1Blocks(context.Background()))

	p := s.p

	batchSize := 100

	var err error
	for i := 0; i < batchSize; i++ {
		to := common.BytesToAddress(testutils.RandomBytes(32))
		_, err = testutils.SendDynamicFeeTx(s.RPCClient.L2, s.TestAddrPrivKey, &to, nil, nil)
		s.Nil(err)
	}

	var preBuiltTxList []*miner.PreBuiltTxList
	for i := 0; i < 3 && len(preBuiltTxList) == 0; i++ {
		preBuiltTxList, err = s.RPCClient.GetPoolContent(
			context.Background(),
			p.proposerAddress,
			p.protocolConfigs.BlockMaxGasLimit,
			rpc.BlockMaxTxListBytes,
			p.LocalAddresses,
			p.MaxProposedTxListsPerEpoch,
			0,
			p.chainConfig,
		)
		time.Sleep(time.Second)
	}
	s.Nil(err)
	s.Equal(true, len(preBuiltTxList) > 0)

	var (
		blockMinGasLimit    uint64 = math.MaxUint64
		blockMinTxListBytes uint64 = math.MaxUint64
	)
	for _, txs := range preBuiltTxList {
		if txs.EstimatedGasUsed <= blockMinGasLimit {
			blockMinGasLimit = txs.EstimatedGasUsed
		} else {
			break
		}
		if txs.BytesLength <= blockMinTxListBytes {
			blockMinTxListBytes = txs.BytesLength
		} else {
			break
		}
	}

	// Start proposer
	p.LocalAddressesOnly = false
	p.MinGasUsed = blockMinGasLimit
	p.MinTxListBytes = blockMinTxListBytes
	p.ProposeInterval = time.Second
	p.MinProposingInternal = time.Minute
	s.Nil(p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestName() {
	s.Equal("proposer", s.p.Name())
}

func (s *ProposerTestSuite) TestProposeOp() {
	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposedV2)
	sub, err := s.p.rpc.TaikoL1.WatchBlockProposedV2(nil, sink, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	to := common.BytesToAddress(testutils.RandomBytes(32))
	_, err = testutils.SendDynamicFeeTx(s.p.rpc.L2, s.TestAddrPrivKey, &to, common.Big1, nil)
	s.Nil(err)

	s.Nil(s.p.ProposeOp(context.Background()))

	var (
		event = <-sink
		meta  = metadata.NewTaikoDataBlockMetadataOntake(event)
	)
	s.Equal(meta.GetCoinbase(), s.p.L2SuggestedFeeRecipient)

	_, isPending, err := s.p.rpc.L1.TransactionByHash(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.p.rpc.L1.TransactionReceipt(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)
}

func (s *ProposerTestSuite) TestProposeEmptyBlockOp() {
	s.p.MinProposingInternal = 1 * time.Second
	s.p.lastProposedAt = time.Now().Add(-10 * time.Second)
	s.Nil(s.p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestProposeTxListOntake() {
	for i := 0; i < int(s.p.protocolConfigs.OntakeForkHeight); i++ {
		s.ProposeAndInsertValidBlock(s.p, s.s)
	}

	l2Head, err := s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.GreaterOrEqual(l2Head.Number.Uint64(), s.p.protocolConfigs.OntakeForkHeight)

	sink := make(chan *bindings.TaikoL1ClientBlockProposedV2)
	sub, err := s.p.rpc.TaikoL1.WatchBlockProposedV2(nil, sink, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()
	s.Nil(s.p.ProposeTxListOntake(context.Background(), []types.Transactions{{}, {}}, common.Hash{}))
	s.Nil(s.s.ProcessL1Blocks(context.Background()))

	var l1Height *big.Int
	for i := 0; i < 2; i++ {
		event := <-sink
		if l1Height == nil {
			l1Height = new(big.Int).SetUint64(event.Raw.BlockNumber)
			continue
		}
		s.Equal(l1Height.Uint64(), event.Raw.BlockNumber)
	}

	newL2head, err := s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(l2Head.Number.Uint64()+2, newL2head.Number.Uint64())
}

func (s *ProposerTestSuite) TestUpdateProposingTicker() {
	s.p.ProposeInterval = 1 * time.Hour
	s.NotPanics(s.p.updateProposingTicker)

	s.p.ProposeInterval = 0
	s.NotPanics(s.p.updateProposingTicker)
}

func (s *ProposerTestSuite) TestStartClose() {
	s.Nil(s.p.Start())
	s.cancel()
	s.NotPanics(func() { s.p.Close(s.p.ctx) })
}

func TestProposerTestSuite(t *testing.T) {
	suite.Run(t, new(ProposerTestSuite))
}
