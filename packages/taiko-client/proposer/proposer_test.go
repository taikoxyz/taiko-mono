package proposer

import (
	"bytes"
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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
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
			L1Endpoint:                  os.Getenv("L1_WS"),
			L2Endpoint:                  os.Getenv("L2_HTTP"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			TaikoInboxAddress:           common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
			BridgeAddress:               common.HexToAddress(os.Getenv("BRIDGE")),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		MinProposingInterval:    0,
		ProposeInterval:         1024 * time.Hour,
		MaxTxListsPerEpoch:      1,
		ProposeBatchTxGasLimit:  10_000_000,
		BlobAllowed:             true,
		FallbackToCalldata:      true,
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
	s.cancel = cancel
}

func (s *ProposerTestSuite) TestProposeWithRevertProtection() {
	s.p.txBuilder = builder.NewBuilderWithFallback(
		s.p.rpc,
		s.p.L1ProposerPrivKey,
		s.TestAddr,
		common.HexToAddress(os.Getenv("TAIKO_INBOX")),
		common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		common.HexToAddress(os.Getenv("PROVER_SET")),
		common.Address{}, // surgeProposerWrapperAddress
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

	metaHash, err := s.p.GetParentMetaHash(context.Background())
	s.Nil(err)

	l2BaseFee, err := s.p.rpc.L2.SuggestGasPrice(context.Background())
	s.Nil(err)

	s.Nil(s.p.ProposeTxLists(context.Background(), []types.Transactions{{}}, metaHash, l2BaseFee, false))
	s.Nil(s.s.ProcessL1Blocks(context.Background()))

	head2, err := s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head2.Number.Uint64(), head.Number.Uint64()+1)
}

func (s *ProposerTestSuite) TestTxPoolContentWithMinTip() {
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

	l2BaseFee, err := s.p.rpc.L2.SuggestGasPrice(context.Background())
	s.Nil(err)

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
			l2BaseFee,
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
			l2BaseFee,
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

	l2BaseFee, err := s.p.rpc.L2.SuggestGasPrice(context.Background())
	s.Nil(err)

	for i := 0; i < 3 && len(preBuiltTxList) == 0; i++ {
		preBuiltTxList, err = s.RPCClient.GetPoolContent(
			context.Background(),
			p.proposerAddress,
			p.protocolConfigs.BlockMaxGasLimit(),
			rpc.BlockMaxTxListBytes,
			[]common.Address{},
			p.MaxTxListsPerEpoch,
			0,
			l2BaseFee,
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
	p.MinProposingInterval = time.Minute
	s.Nil(p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestName() {
	s.Equal("proposer", s.p.Name())
}

func (s *ProposerTestSuite) TestProposeOp() {
	// Propose txs in L2 execution engine's mempool
	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchProposed)
	sub1, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink1)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
	}()

	to := common.BytesToAddress(testutils.RandomBytes(32))
	_, err = testutils.SendDynamicFeeTx(s.p.rpc.L2, s.TestAddrPrivKey, &to, common.Big1, nil)
	s.Nil(err)

	s.Nil(s.p.ProposeOp(context.Background()))

	event := <-sink1
	meta := metadata.NewTaikoDataBlockMetadataPacaya(event)
	s.Equal(meta.GetCoinbase(), s.p.L2SuggestedFeeRecipient)

	_, isPending, err := s.p.rpc.L1.TransactionByHash(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.p.rpc.L1.TransactionReceipt(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)
}

func (s *ProposerTestSuite) TestProposeEmptyBlockOp() {
	s.p.MinProposingInterval = 1 * time.Second
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
			s.Nil(err)
			txsBatch[i] = append(txsBatch[i], tx)
		}
	}

	l2BaseFee, err := s.p.rpc.L2.SuggestGasPrice(context.Background())
	s.Nil(err)

	s.Nil(s.p.ProposeTxListPacaya(context.Background(), txsBatch, common.Hash{}, l2BaseFee, false))
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

func (s *ProposerTestSuite) TestBridgeMessageMonitoring() {
	// Start the proposer first to ensure subscription is active
	s.Nil(s.p.Start())
	defer func() {
		s.cancel()
		s.NotPanics(func() { s.p.Close(s.p.ctx) })
	}()

	bridgeAddr := s.p.Config.ClientConfig.BridgeAddress
	s.NotEqual(bridgeAddr, common.Address{}, "Bridge address should not be zero")
	log.Info("Using Bridge address for test", "address", bridgeAddr.Hex())

	// Get the Bridge contract ABI
	bridgeABI, err := bridge.BridgeMetaData.GetAbi()
	s.Nil(err)

	// Get the sendMessage method
	sendMessageMethod := bridgeABI.Methods["sendMessage"]
	s.NotNil(sendMessageMethod.ID, "Failed to get sendMessage method ID")

	// Helper function to create a Bridge message transaction
	createBridgeMessageTx := func(nonce uint64) *types.Transaction {
		testData := append(sendMessageMethod.ID, testutils.RandomBytes(100)...)

		// Get current base fee
		header, err := s.p.rpc.L1.HeaderByNumber(context.Background(), nil)
		s.Nil(err)
		baseFee := header.BaseFee

		// Get chain ID
		chainID := s.p.rpc.L1.ChainID

		// Create a signed transaction with very low gas price to keep it pending
		gasFeeCap := new(big.Int).Add(baseFee, big.NewInt(1)) // Set max fee per gas just slightly above base fee
		gasTipCap := big.NewInt(1)                            // Set priority fee (tip) very low

		signer := types.LatestSignerForChainID(chainID)
		tx := types.NewTx(&types.DynamicFeeTx{
			ChainID:   chainID,
			Nonce:     nonce,
			To:        &bridgeAddr,
			Value:     common.Big1,
			Gas:       100000,
			GasFeeCap: gasFeeCap,
			GasTipCap: gasTipCap,
			Data:      testData,
		})

		signedTx, err := types.SignTx(tx, signer, s.TestAddrPrivKey)
		s.Nil(err)

		err = s.p.rpc.L1.SendTransaction(context.Background(), signedTx)
		s.Nil(err)

		log.Info(
			"Sent Bridge message transaction",
			"hash", signedTx.Hash().Hex(),
			"from", s.TestAddr.Hex(),
			"to", bridgeAddr.Hex(),
			"nonce", nonce,
			"value", signedTx.Value(),
			"gasFeeCap", gasFeeCap,
			"gasTipCap", gasTipCap,
		)

		return signedTx
	}

	// Helper function to wait for transaction processing
	waitForProcessing := func() {
		time.Sleep(2 * time.Second)
	}

	s.Run("Valid Bridge Message Transaction", func() {
		testNonce, err := s.p.rpc.L1.NonceAt(context.Background(), s.TestAddr, nil)
		s.Nil(err)

		signedTx := createBridgeMessageTx(testNonce)
		waitForProcessing()

		// Verify the transaction was detected and stored
		s.p.bridgeMsgMu.RLock()
		detected := s.p.pendingBridgeMessages[signedTx.Hash()]
		s.p.bridgeMsgMu.RUnlock()

		s.NotNil(detected, "Bridge message transaction should be detected")
		s.Equal(signedTx.Hash(), detected.Hash(), "Detected transaction hash should match sent transaction")
		s.Equal(bridgeAddr, *detected.To(), "Detected transaction should be to Bridge contract")
		s.True(bytes.HasPrefix(detected.Data(), sendMessageMethod.ID), "Transaction should have sendMessage selector")
	})

	s.Run("Non-Bridge Transaction", func() {
		testNonce, err := s.p.rpc.L1.NonceAt(context.Background(), s.TestAddr, nil)
		s.Nil(err)

		randomAddr := common.BytesToAddress(testutils.RandomBytes(20))
		nonBridgeTx, err := testutils.AssembleAndSendTestTx(
			s.p.rpc.L1,
			s.TestAddrPrivKey,
			testNonce,
			&randomAddr,
			common.Big1,
			testutils.RandomBytes(100),
		)
		s.Nil(err)
		s.NotNil(nonBridgeTx, "Non-bridge transaction should not be nil")

		waitForProcessing()

		// Verify the non-Bridge transaction was not detected
		s.p.bridgeMsgMu.RLock()
		notDetected := s.p.pendingBridgeMessages[nonBridgeTx.Hash()]
		s.p.bridgeMsgMu.RUnlock()

		s.Nil(notDetected, "Non-Bridge transaction should not be detected")
	})

	s.Run("Invalid Bridge Transaction", func() {
		testNonce, err := s.p.rpc.L1.NonceAt(context.Background(), s.TestAddr, nil)
		s.Nil(err)

		invalidSelectorTx, err := testutils.AssembleAndSendTestTx(
			s.p.rpc.L1,
			s.TestAddrPrivKey,
			testNonce,
			&bridgeAddr,
			common.Big1,
			testutils.RandomBytes(100),
		)
		s.Nil(err)
		s.NotNil(invalidSelectorTx, "Invalid selector transaction should not be nil")

		waitForProcessing()

		// Verify the Bridge transaction without sendMessage selector was not detected
		s.p.bridgeMsgMu.RLock()
		notDetectedInvalid := s.p.pendingBridgeMessages[invalidSelectorTx.Hash()]
		s.p.bridgeMsgMu.RUnlock()

		s.Nil(notDetectedInvalid, "Bridge transaction without sendMessage selector should not be detected")
	})

	s.Run("Cleanup After Proposal", func() {
		// First create a valid bridge message to ensure we have something to clean up
		testNonce, err := s.p.rpc.L1.NonceAt(context.Background(), s.TestAddr, nil)
		s.Nil(err)

		createBridgeMessageTx(testNonce)
		waitForProcessing()

		// Verify we have a pending message
		s.p.bridgeMsgMu.RLock()
		initialMsgs := len(s.p.pendingBridgeMessages)
		s.p.bridgeMsgMu.RUnlock()
		s.Greater(initialMsgs, 0, "Should have pending messages before cleanup")

		// Test that detected transactions are cleared after being proposed
		s.Nil(s.p.ProposeOp(context.Background()))

		s.p.bridgeMsgMu.RLock()
		remainingMsgs := len(s.p.pendingBridgeMessages)
		s.p.bridgeMsgMu.RUnlock()

		s.Equal(0, remainingMsgs, "Pending messages should be cleared after proposing")
	})
}

func (s *ProposerTestSuite) TestFindHighestBaseFeeInBatch() {
	// Test with empty batch
	s.Run("EmptyBatch", func() {
		emptyBatch := []types.Transactions{}
		highestFee := s.p.findHighestBaseFeeInBatch(emptyBatch)
		s.Nil(highestFee, "Empty batch should return nil")
	})

	// Test with single transaction
	s.Run("SingleTransaction", func() {
		gasFeeCap := big.NewInt(1000000000) // 1 gwei
		tx := types.NewTx(&types.DynamicFeeTx{
			ChainID:   s.RPCClient.L2.ChainID,
			Nonce:     0,
			GasFeeCap: gasFeeCap,
			GasTipCap: big.NewInt(100000000),
			Gas:       21000,
			To:        &s.TestAddr,
			Value:     common.Big0,
		})
		batch := []types.Transactions{{tx}}
		highestFee := s.p.findHighestBaseFeeInBatch(batch)
		s.NotNil(highestFee)
		s.Equal(gasFeeCap.Int64(), highestFee.Int64())
	})

	// Test with multiple transactions having different gas fees
	s.Run("MultipleTransactions", func() {
		gasFees := []*big.Int{
			big.NewInt(1000000000),  // 1 gwei
			big.NewInt(5000000000),  // 5 gwei (highest)
			big.NewInt(2000000000),  // 2 gwei
			big.NewInt(3000000000),  // 3 gwei
		}

		var txs types.Transactions
		for i, fee := range gasFees {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: fee,
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			txs = append(txs, tx)
		}

		batch := []types.Transactions{txs}
		highestFee := s.p.findHighestBaseFeeInBatch(batch)
		s.NotNil(highestFee)
		s.Equal(int64(5000000000), highestFee.Int64())
	})

	// Test with legacy transactions (using GasPrice)
	s.Run("LegacyTransactions", func() {
		signer := types.LatestSignerForChainID(s.RPCClient.L2.ChainID)

		legacyTx := types.NewTx(&types.LegacyTx{
			Nonce:    0,
			GasPrice: big.NewInt(3000000000), // 3 gwei
			Gas:      21000,
			To:       &s.TestAddr,
			Value:    common.Big0,
		})
		signedLegacyTx, err := types.SignTx(legacyTx, signer, s.TestAddrPrivKey)
		s.Nil(err)

		dynamicTx := types.NewTx(&types.DynamicFeeTx{
			ChainID:   s.RPCClient.L2.ChainID,
			Nonce:     1,
			GasFeeCap: big.NewInt(2000000000), // 2 gwei
			GasTipCap: big.NewInt(100000000),
			Gas:       21000,
			To:        &s.TestAddr,
			Value:     common.Big0,
		})

		batch := []types.Transactions{{signedLegacyTx, dynamicTx}}
		highestFee := s.p.findHighestBaseFeeInBatch(batch)
		s.NotNil(highestFee)
		s.Equal(int64(3000000000), highestFee.Int64(), "Legacy transaction's GasPrice should be used")
	})

	// Test with multiple batches
	s.Run("MultipleBatches", func() {
		batch1 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     0,
				GasFeeCap: big.NewInt(2000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		batch2 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     1,
				GasFeeCap: big.NewInt(7000000000), // Highest
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		batch3 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     2,
				GasFeeCap: big.NewInt(4000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		batches := []types.Transactions{batch1, batch2, batch3}
		highestFee := s.p.findHighestBaseFeeInBatch(batches)
		s.NotNil(highestFee)
		s.Equal(int64(7000000000), highestFee.Int64())
	})
}

func (s *ProposerTestSuite) TestFilterTxsByBaseFee() {
	s.Run("EmptyBatch", func() {
		emptyBatch := []types.Transactions{}
		filtered := s.p.filterTxsByBaseFee(emptyBatch, big.NewInt(1000000000))
		s.Equal(0, len(filtered), "Filtering empty batch should return empty result")
	})

	s.Run("AllTransactionsMeetThreshold", func() {
		minBaseFee := big.NewInt(1000000000) // 1 gwei

		var txs types.Transactions
		for i := 0; i < 3; i++ {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: big.NewInt(2000000000), // All above threshold
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			txs = append(txs, tx)
		}

		batch := []types.Transactions{txs}
		filtered := s.p.filterTxsByBaseFee(batch, minBaseFee)
		s.Equal(1, len(filtered), "Should have one batch")
		s.Equal(3, len(filtered[0]), "All transactions should pass filter")
	})

	s.Run("SomeTransactionsBelowThreshold", func() {
		minBaseFee := big.NewInt(3000000000) // 3 gwei

		gasFees := []*big.Int{
			big.NewInt(5000000000), // Above threshold - should pass
			big.NewInt(2000000000), // Below threshold - should filter out
			big.NewInt(4000000000), // Above threshold - should pass
			big.NewInt(1000000000), // Below threshold - should filter out
			big.NewInt(3000000000), // Equal to threshold - should pass
		}

		var txs types.Transactions
		for i, fee := range gasFees {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: fee,
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			txs = append(txs, tx)
		}

		batch := []types.Transactions{txs}
		filtered := s.p.filterTxsByBaseFee(batch, minBaseFee)
		s.Equal(1, len(filtered), "Should have one batch")
		s.Equal(3, len(filtered[0]), "Only 3 transactions should pass (5, 4, and 3 gwei)")

		// Verify the filtered transactions are the correct ones
		s.True(filtered[0][0].GasFeeCap().Cmp(minBaseFee) >= 0)
		s.True(filtered[0][1].GasFeeCap().Cmp(minBaseFee) >= 0)
		s.True(filtered[0][2].GasFeeCap().Cmp(minBaseFee) >= 0)
	})

	s.Run("AllTransactionsBelowThreshold", func() {
		minBaseFee := big.NewInt(10000000000) // 10 gwei - very high

		var txs types.Transactions
		for i := 0; i < 3; i++ {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: big.NewInt(2000000000), // All below threshold
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			txs = append(txs, tx)
		}

		batch := []types.Transactions{txs}
		filtered := s.p.filterTxsByBaseFee(batch, minBaseFee)
		s.Equal(0, len(filtered), "No transactions should pass filter")
	})

	s.Run("MultipleBatchesWithMixedResults", func() {
		minBaseFee := big.NewInt(3000000000) // 3 gwei

		// Batch 1: Some transactions pass
		batch1 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     0,
				GasFeeCap: big.NewInt(5000000000), // Pass
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     1,
				GasFeeCap: big.NewInt(1000000000), // Fail
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		// Batch 2: All transactions fail
		batch2 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     2,
				GasFeeCap: big.NewInt(1000000000), // Fail
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		// Batch 3: All transactions pass
		batch3 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     3,
				GasFeeCap: big.NewInt(4000000000), // Pass
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     4,
				GasFeeCap: big.NewInt(3000000000), // Pass
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		batches := []types.Transactions{batch1, batch2, batch3}
		filtered := s.p.filterTxsByBaseFee(batches, minBaseFee)

		// Should have 2 batches (batch1 with 1 tx and batch3 with 2 txs)
		// Batch2 is completely filtered out
		s.Equal(2, len(filtered), "Should have 2 batches (batch2 filtered out)")
		s.Equal(1, len(filtered[0]), "Batch1 should have 1 transaction")
		s.Equal(2, len(filtered[1]), "Batch3 should have 2 transactions")
	})

	s.Run("LegacyTransactionsFiltering", func() {
		minBaseFee := big.NewInt(3000000000) // 3 gwei
		signer := types.LatestSignerForChainID(s.RPCClient.L2.ChainID)

		// Legacy tx with high gas price (should pass)
		legacyTxHigh := types.NewTx(&types.LegacyTx{
			Nonce:    0,
			GasPrice: big.NewInt(4000000000),
			Gas:      21000,
			To:       &s.TestAddr,
			Value:    common.Big0,
		})
		signedLegacyHigh, err := types.SignTx(legacyTxHigh, signer, s.TestAddrPrivKey)
		s.Nil(err)

		// Legacy tx with low gas price (should fail)
		legacyTxLow := types.NewTx(&types.LegacyTx{
			Nonce:    1,
			GasPrice: big.NewInt(1000000000),
			Gas:      21000,
			To:       &s.TestAddr,
			Value:    common.Big0,
		})
		signedLegacyLow, err := types.SignTx(legacyTxLow, signer, s.TestAddrPrivKey)
		s.Nil(err)

		// Dynamic tx (should pass)
		dynamicTx := types.NewTx(&types.DynamicFeeTx{
			ChainID:   s.RPCClient.L2.ChainID,
			Nonce:     2,
			GasFeeCap: big.NewInt(3500000000),
			GasTipCap: big.NewInt(100000000),
			Gas:       21000,
			To:        &s.TestAddr,
			Value:     common.Big0,
		})

		batch := []types.Transactions{{signedLegacyHigh, signedLegacyLow, dynamicTx}}
		filtered := s.p.filterTxsByBaseFee(batch, minBaseFee)

		s.Equal(1, len(filtered), "Should have one batch")
		s.Equal(2, len(filtered[0]), "Should have 2 transactions (high legacy and dynamic)")
	})
}

func (s *ProposerTestSuite) TestCountTxsInBatch() {
	s.Run("EmptyBatch", func() {
		emptyBatch := []types.Transactions{}
		count := countTxsInBatch(emptyBatch)
		s.Equal(uint64(0), count)
	})

	s.Run("SingleBatchWithMultipleTxs", func() {
		var txs types.Transactions
		for i := 0; i < 5; i++ {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			txs = append(txs, tx)
		}
		batch := []types.Transactions{txs}
		count := countTxsInBatch(batch)
		s.Equal(uint64(5), count)
	})

	s.Run("MultipleBatches", func() {
		batch1 := types.Transactions{}
		batch2 := types.Transactions{}
		batch3 := types.Transactions{}

		for i := 0; i < 3; i++ {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			batch1 = append(batch1, tx)
		}

		for i := 3; i < 8; i++ {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			batch2 = append(batch2, tx)
		}

		for i := 8; i < 10; i++ {
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     uint64(i),
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			})
			batch3 = append(batch3, tx)
		}

		batches := []types.Transactions{batch1, batch2, batch3}
		count := countTxsInBatch(batches)
		s.Equal(uint64(10), count, "Total should be 3 + 5 + 2 = 10")
	})

	s.Run("BatchesWithEmptyList", func() {
		batch1 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     0,
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}
		batch2 := types.Transactions{} // Empty
		batch3 := types.Transactions{
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     1,
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
			types.NewTx(&types.DynamicFeeTx{
				ChainID:   s.RPCClient.L2.ChainID,
				Nonce:     2,
				GasFeeCap: big.NewInt(1000000000),
				GasTipCap: big.NewInt(100000000),
				Gas:       21000,
				To:        &s.TestAddr,
				Value:     common.Big0,
			}),
		}

		batches := []types.Transactions{batch1, batch2, batch3}
		count := countTxsInBatch(batches)
		s.Equal(uint64(3), count, "Should count 1 + 0 + 2 = 3")
	})
}

func TestProposerTestSuite(t *testing.T) {
	suite.Run(t, new(ProposerTestSuite))
}
