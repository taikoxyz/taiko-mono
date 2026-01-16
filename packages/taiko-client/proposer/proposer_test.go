package proposer

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"maps"
	"math"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

type ProposerTestSuite struct {
	testutils.ClientTestSuite
	s      *event.Syncer
	p      *Proposer
	cancel context.CancelFunc
}

func (s *ProposerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	state2, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)

	syncer, err := event.NewSyncer(
		context.Background(),
		s.RPCClient,
		state2,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 1*time.Hour),
		s.BlobServer.URL(),
		nil,
	)
	s.Nil(err)
	s.s = syncer

	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		p                 = new(Proposer)
	)

	ctx, cancel := context.WithCancel(context.Background())
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	log.Info("Proposer address", "address", crypto.PubkeyToAddress(l1ProposerPrivKey.PublicKey).String())

	s.Nil(p.InitFromConfig(ctx, &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  os.Getenv("L1_HTTP"),
			L2Endpoint:                  os.Getenv("L2_WS"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
			ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		MinProposingInternal:    0,
		ProposeInterval:         1024 * time.Hour,
		MaxTxListsPerEpoch:      1,
		ProposeBatchTxGasLimit:  10_000_000,
		BlobAllowed:             true,
		FallbackToCalldata:      true,
		TxmgrConfigs: &txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_HTTP"),
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
			L1RPCURL:                  os.Getenv("L1_HTTP"),
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
	s.cancel = cancel
}

func (s *ProposerTestSuite) TestProposeWithRevertProtection() {
	s.p.txBuilder = builder.NewBuilderWithFallback(
		s.p.rpc,
		s.p.L1ProposerPrivKey,
		s.TestAddr,
		common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		common.HexToAddress(os.Getenv("PROVER_SET")),
		10_000_000,
		s.p.chainConfig,
		s.p.txmgrSelector,
		true,
		true,
		true,
	)
	s.Nil(s.s.ProcessL1Blocks(context.Background()))

	s.SetL1Automine(false)
	defer s.SetL1Automine(true)
	head, err := s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.SetIntervalMining(1)

	s.Nil(s.p.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(s.s.ProcessL1Blocks(context.Background()))

	head2, err := s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head2.Number.Uint64(), head.Number.Uint64()+1)
}

func (s *ProposerTestSuite) TestTxPoolContentWithMinTip() {
	if os.Getenv("L2_NODE") != "l2_geth" {
		s.T().Skip("This test is only applicable for L2 Geth node")
	}
	s.ForkIntoShasta(s.p, s.s)
	var (
		txsCountForEachSender = 300
		sendersCount          = 5
		originalNonceMap      = make(map[common.Address]uint64)
		privateKeys           []*ecdsa.PrivateKey
		testAddresses         []common.Address
	)
	for i := 0; i < sendersCount; i++ {
		key, err := crypto.GenerateKey()
		s.Nil(err)
		privateKeys = append(privateKeys, key)

		address := crypto.PubkeyToAddress(key.PublicKey)
		testAddresses = append(testAddresses, address)
		nonce, err := s.RPCClient.L2.NonceAt(
			context.Background(),
			crypto.PubkeyToAddress(s.KeyFromEnv("L1_CONTRACT_OWNER_PRIVATE_KEY").PublicKey),
			nil,
		)
		s.Nil(err)
		// Send ETHs to the new sender address
		_, err = testutils.AssembleAndSendTestTx(
			s.RPCClient.L2,
			s.KeyFromEnv("L1_CONTRACT_OWNER_PRIVATE_KEY"),
			nonce+uint64(i),
			&address,
			new(big.Int).SetUint64(10*params.Ether),
			nil,
		)
		s.Nil(err)
	}

	// Empty mempool at first.
	for {
		poolContent, err := s.RPCClient.GetPoolContent(
			context.Background(),
			s.p.proposerAddress,
			s.p.protocolConfigs.BlockMaxGasLimit(),
			rpc.BlockMaxTxListBytes,
			[]common.Address{},
			10,
			0,
			s.p.chainConfig,
			s.p.protocolConfigs.BaseFeeConfig(),
		)
		s.Nil(err)

		if len(poolContent) > 0 {
			s.Nil(s.p.ProposeOp(context.Background()))
			s.Nil(s.s.ProcessL1Blocks(context.Background()))
			continue
		}
		break
	}

	for _, address := range testAddresses {
		balance, err := s.RPCClient.L2.BalanceAt(context.Background(), address, nil)
		s.Nil(err)
		s.GreaterOrEqual(balance.Uint64(), uint64(10*params.Ether))
	}

	allTxs := make([]*types.Transaction, 0)
	for _, key := range privateKeys {
		transactOpts, err := bind.NewKeyedTransactorWithChainID(key, s.RPCClient.L2.ChainID)
		s.Nil(err)
		nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), transactOpts.From)
		s.Nil(err)
		originalNonceMap[transactOpts.From] = nonce
		// Send txsCountForEachSender * len(privateKeys) transactions to mempool
		for i := 0; i < txsCountForEachSender; i++ {
			tx, err := testutils.AssembleAndSendTestTx(
				s.RPCClient.L2, key, nonce+uint64(i), &transactOpts.From, common.Big0, nil,
			)
			s.Nil(err)
			allTxs = append(allTxs, tx)
		}
	}
	s.Equal(txsCountForEachSender*len(privateKeys), len(allTxs))

	for _, testCase := range []struct {
		blockMaxGasLimit     uint32
		blockMaxTxListBytes  uint64
		maxTransactionsLists uint64
		txLengthList         []int
	}{
		{
			s.p.protocolConfigs.BlockMaxGasLimit(),
			rpc.BlockMaxTxListBytes,
			s.p.MaxTxListsPerEpoch,
			[]int{txsCountForEachSender * len(privateKeys)},
		},
		{
			s.p.protocolConfigs.BlockMaxGasLimit(),
			rpc.BlockMaxTxListBytes,
			s.p.MaxTxListsPerEpoch * uint64(len(privateKeys)),
			[]int{txsCountForEachSender * len(privateKeys)},
		},
		{
			s.p.protocolConfigs.BlockMaxGasLimit() / 50,
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
			[]common.Address{},
			testCase.maxTransactionsLists,
			0,
			s.p.chainConfig,
			s.p.protocolConfigs.BaseFeeConfig(),
		)
		s.Nil(err)

		nonceMap := maps.Clone(originalNonceMap)
		// Check the order of nonce.
		for _, txList := range poolContent {
			for _, tx := range txList.TxList {
				sender, err := types.Sender(types.LatestSignerForChainID(s.RPCClient.L2.ChainID), tx)
				s.Nil(err)
				s.Equalf(nonceMap[sender], tx.Nonce(),
					fmt.Sprintf(
						"incorrect nonce of %s, expect: %d, actual: %d",
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
	defer s.Nil(s.s.ProcessL1Blocks(context.Background()))
	s.ForkIntoShasta(s.p, s.s)

	var (
		p              = s.p
		batchSize      = 100
		preBuiltTxList []*miner.PreBuiltTxList
		err            error
	)

	for i := 0; i < batchSize; i++ {
		to := common.BytesToAddress(testutils.RandomBytes(32))
		_, err = testutils.SendDynamicFeeTx(s.RPCClient.L2, s.TestAddrPrivKey, &to, nil, nil)
		s.Nil(err)
	}

	for i := 0; i < 3 && len(preBuiltTxList) == 0; i++ {
		preBuiltTxList, err = s.RPCClient.GetPoolContent(
			context.Background(),
			p.proposerAddress,
			p.protocolConfigs.BlockMaxGasLimit(),
			rpc.BlockMaxTxListBytes,
			[]common.Address{},
			p.MaxTxListsPerEpoch,
			0,
			p.chainConfig,
			p.protocolConfigs.BaseFeeConfig(),
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
	p.ProposeInterval = time.Second
	p.MinProposingInternal = time.Minute
	s.Nil(p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestName() {
	s.Equal("proposer", s.p.Name())
}

func (s *ProposerTestSuite) TestProposeOp() {
	s.ForkIntoShasta(s.p, s.s)

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	cursor := testutils.NewProposalEventCursor(l1Head.Number.Uint64())
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	to := common.BytesToAddress(testutils.RandomBytes(32))
	_, err = testutils.SendDynamicFeeTx(s.p.rpc.L2, s.TestAddrPrivKey, &to, common.Big1, nil)
	s.Nil(err)

	s.Nil(s.p.ProposeOp(context.Background()))

	meta, _, _, err := s.WaitForNextProposalEvent(ctx, cursor)
	s.Nil(err)
	s.True(meta.IsShasta())

	_, isPending, err := s.p.rpc.L1.TransactionByHash(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.p.rpc.L1.TransactionReceipt(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)
}

func (s *ProposerTestSuite) TestProposeEmptyBlockOp() {
	s.ForkIntoShasta(s.p, s.s)
	s.p.MinProposingInternal = 1 * time.Second
	s.p.lastProposedAt = time.Now().Add(-10 * time.Second)
	s.Nil(s.p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestUpdateProposingTicker() {
	s.p.ProposeInterval = 1 * time.Hour
	s.NotPanics(s.p.updateProposingTicker)

	s.p.ProposeInterval = 0
	s.NotPanics(s.p.updateProposingTicker)
}

func (s *ProposerTestSuite) TestProposeMultiBlobsInOneBatch() {
	s.ForkIntoShasta(s.p, s.s)

	l2Head1, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose a batch which contains two blobs.
	var (
		batchSize    = 2
		txNumInBatch = 500
		txsBatch     = make([]types.Transactions, batchSize)
	)
	testAddrNonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, l2Head1.Number)
	s.Nil(err)

	for i := 0; i < batchSize; i++ {
		for j := 0; j < txNumInBatch; j++ {
			to := common.BytesToAddress(testutils.RandomBytes(32))

			tx, err := testutils.AssembleAndSendTestTx(
				s.RPCClient.L2,
				s.TestAddrPrivKey,
				uint64(i*txNumInBatch+int(testAddrNonce)+j),
				&to,
				common.Big1,
				[]byte{1},
			)
			if err != nil {
				s.Equal("replacement transaction underpriced", err.Error())
			}
			txsBatch[i] = append(txsBatch[i], tx)
		}
	}

	s.Nil(s.p.ProposeTxLists(context.Background(), txsBatch))
	s.Nil(s.s.ProcessL1Blocks(context.Background()))

	l2Head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64()+uint64(batchSize), l2Head2.Number().Uint64())
	s.Equal(txNumInBatch+1, l2Head2.Transactions().Len())

	l2Head3, err := s.RPCClient.L2.BlockByHash(context.Background(), l2Head2.ParentHash())
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64()+uint64(batchSize-1), l2Head3.Number().Uint64())
	s.Equal(txNumInBatch+1, l2Head3.Transactions().Len())
}

func (s *ProposerTestSuite) TestStartClose() {
	s.Nil(s.p.Start())
	s.cancel()
	s.NotPanics(func() { s.p.Close(s.p.ctx) })
}

func TestProposerTestSuite(t *testing.T) {
	suite.Run(t, new(ProposerTestSuite))
}
