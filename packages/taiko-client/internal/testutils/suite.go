package testutils

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

type ClientTestSuite struct {
	suite.Suite
	testnetL1SnapshotID string
	once                sync.Once
	RPCClient           *rpc.Client
	TestAddrPrivKey     *ecdsa.PrivateKey
	TestAddr            common.Address
	BlobServer          *MemoryBlobServer
}

func (s *ClientTestSuite) SetupTest() {
	utils.LoadEnv()
	// Default logger
	ver, err := strconv.Atoi(os.Getenv("VERBOSITY"))
	s.Nil(err)
	glogger := log.NewGlogHandler(log.NewTerminalHandler(os.Stdout, true))
	glogger.Verbosity(log.FromLegacyLevel(ver))
	log.SetDefault(log.NewLogger(glogger))

	var (
		testAddrPrivKey   = s.KeyFromEnv("TEST_ACCOUNT_PRIVATE_KEY")
		ownerPrivKey      = s.KeyFromEnv("L1_CONTRACT_OWNER_PRIVATE_KEY")
		l1ProverPrivKey   = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
	)

	s.TestAddrPrivKey = testAddrPrivKey
	s.TestAddr = crypto.PubkeyToAddress(testAddrPrivKey.PublicKey)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	rpcCli, err := rpc.NewClient(context.Background(), &rpc.ClientConfig{
		L1Endpoint:                  os.Getenv("L1_WS"),
		L2Endpoint:                  os.Getenv("L2_WS"),
		PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   string(jwtSecret),
	})
	s.Nil(err)
	s.RPCClient = rpcCli

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Less(l1Head.Time, s.RPCClient.ShastaClients.ForkTime)
	s.SetBlockTimestampInterval(12 * time.Second)

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	for _, key := range []*ecdsa.PrivateKey{l1ProposerPrivKey, l1ProverPrivKey} {
		s.enableProver(ownerPrivKey, crypto.PubkeyToAddress(key.PublicKey))
	}

	bondBalance, err := rpcCli.PacayaClients.TaikoInbox.BondBalanceOf(nil, common.HexToAddress(os.Getenv("PROVER_SET")))
	s.Nil(err)

	if bondBalance.Cmp(common.Big0) == 0 {
		s.sendBondTokens(ownerPrivKey, crypto.PubkeyToAddress(l1ProposerPrivKey.PublicKey))
		s.sendBondTokens(ownerPrivKey, crypto.PubkeyToAddress(l1ProverPrivKey.PublicKey))
		s.sendBondTokens(ownerPrivKey, common.HexToAddress(os.Getenv("PROVER_SET")))

		s.depositTokens(l1ProposerPrivKey)
		s.depositTokens(l1ProverPrivKey)
		s.depositProverSetTokens(ownerPrivKey)
	}

	// At the beginning of each test, we ensure the L2 chain has been reset to the base block (height: 1).
	s.once.Do(func() {
		s.testnetL1SnapshotID = s.SetL1Snapshot()
		s.resetToBaseBlock(l1ProposerPrivKey)
	})

	s.BlobServer = NewMemoryBlobServer()
}

func (s *ClientTestSuite) enableProver(key *ecdsa.PrivateKey, address common.Address) {
	t := s.TxMgr("enableProver", key)

	proverSetAddress := common.HexToAddress(os.Getenv("PROVER_SET"))

	enabled, err := s.RPCClient.PacayaClients.ProverSet.IsProver(nil, address)
	s.Nil(err)

	if !enabled {
		log.Info("Enable prover / proposer in ProverSet", "address", address.Hex())

		data, err := encoding.ProverSetABI.Pack("enableProver", address, true)
		s.Nil(err)
		_, err = t.Send(context.Background(), txmgr.TxCandidate{
			TxData: data,
			To:     &proverSetAddress,
		})
		s.Nil(err)

		enabled, err = s.RPCClient.PacayaClients.ProverSet.IsProver(nil, address)
		s.Nil(err)
		s.True(enabled)
	}
}

func (s *ClientTestSuite) sendBondTokens(key *ecdsa.PrivateKey, recipient common.Address) {
	protocolConfig, err := s.RPCClient.GetProtocolConfigs(nil)
	s.Nil(err)

	amount := new(big.Int).Mul(protocolConfig.LivenessBond(), common.Big256)

	log.Info("Send bond tokens", "recipient", recipient.Hex(), "amount", utils.WeiToEther(amount))

	opts, err := bind.NewKeyedTransactorWithChainID(key, s.RPCClient.L1.ChainID)
	s.Nil(err)

	_, err = s.RPCClient.PacayaClients.TaikoToken.Transfer(opts, recipient, amount)
	s.Nil(err)
}

func (s *ClientTestSuite) depositTokens(key *ecdsa.PrivateKey) {
	t := s.TxMgr("setAllowance", key)

	var (
		taikoTokenAddress = common.HexToAddress(os.Getenv("TAIKO_TOKEN"))
		taikoInboxAddress = common.HexToAddress(os.Getenv("PACAYA_INBOX"))
	)

	log.Info("Deposit tokens", "address", crypto.PubkeyToAddress(key.PublicKey).Hex())

	balance, err := s.RPCClient.PacayaClients.TaikoToken.BalanceOf(nil, crypto.PubkeyToAddress(key.PublicKey))
	s.Nil(err)
	s.Greater(balance.Cmp(common.Big0), 0)

	data, err := encoding.TaikoTokenABI.Pack("approve", common.HexToAddress(os.Getenv("PACAYA_INBOX")), balance)
	s.Nil(err)

	_, err = t.Send(context.Background(), txmgr.TxCandidate{TxData: data, To: &taikoTokenAddress})
	s.Nil(err)

	data, err = encoding.TaikoInboxABI.Pack("depositBond", balance)
	s.Nil(err)

	_, err = t.Send(context.Background(), txmgr.TxCandidate{TxData: data, To: &taikoInboxAddress})
	s.Nil(err)
}

func (s *ClientTestSuite) depositProverSetTokens(key *ecdsa.PrivateKey) {
	t := s.TxMgr("setProverSetAllowance", key)

	var proverSetAddress = common.HexToAddress(os.Getenv("PROVER_SET"))

	balance, err := s.RPCClient.PacayaClients.TaikoToken.BalanceOf(nil, proverSetAddress)
	s.Nil(err)
	s.Greater(balance.Cmp(common.Big0), 0)

	log.Info("Deposit ProverSet tokens", "address", proverSetAddress.Hex(), "balance", utils.WeiToEther(balance))

	data, err := encoding.ProverSetPacayaABI.Pack("depositBond", balance)
	s.Nil(err)

	_, err = t.Send(context.Background(), txmgr.TxCandidate{TxData: data, To: &proverSetAddress})
	s.Nil(err)
}

func (s *ClientTestSuite) TxMgr(name string, key *ecdsa.PrivateKey) txmgr.TxManager {
	txmgr, err := txmgr.NewSimpleTxManager(
		name,
		log.Root(),
		new(metrics.NoopTxMetrics),
		txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(key)),
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
	)
	s.Nil(err)
	return NewMemoryBlobTxMgr(s.RPCClient, txmgr, s.BlobServer)
}

func (s *ClientTestSuite) KeyFromEnv(envName string) *ecdsa.PrivateKey {
	key, err := crypto.ToECDSA(common.FromHex(os.Getenv(envName)))
	s.Nil(err)
	return key
}

func (s *ClientTestSuite) TearDownTest() {
	s.RevertL1Snapshot(s.testnetL1SnapshotID)
	s.testnetL1SnapshotID = s.SetL1Snapshot()
	s.resetToBaseBlock(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY"))
	_, err := s.RPCClient.L2Engine.SetHeadL1Origin(context.Background(), common.Big1)
	s.Nil(err)
	s.BlobServer.Close()
}

func (s *ClientTestSuite) TearDownSuite() {
	s.RevertL1Snapshot(s.testnetL1SnapshotID)
}

func (s *ClientTestSuite) SetHead(headNum *big.Int) {
	// For geth node, we can set the head directly.
	if os.Getenv("L2_NODE") == "l2_geth" {
		s.Nil(rpc.SetHead(context.Background(), s.RPCClient.L2, headNum))
		return
	}

	// For other nodes, we need to use the engine API to set the head instead,
	// to reset the chain head to a block which is already in the canonical chain,
	// we need to fork the chain to a block with different attributes at the same height
	// at first, then set the canonical head to the block we want.
	block, err := s.RPCClient.L2.BlockByNumber(context.Background(), headNum)
	s.Nil(err)

	l1Origin, err := s.RPCClient.L2.L1OriginByID(context.Background(), block.Number())
	s.Nil(err)

	b, err := rlp.EncodeToBytes(block.Transactions())
	s.Nil(err)

	originalCoinbase := block.Coinbase()
	attributes := &engine.PayloadAttributes{
		Timestamp:             block.Time(),
		Random:                block.MixDigest(),
		SuggestedFeeRecipient: originalCoinbase,
		Withdrawals:           []*types.Withdrawal{},
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: block.Coinbase(),
			GasLimit:    block.GasLimit(),
			Timestamp:   block.Time(),
			TxList:      b,
			MixHash:     block.MixDigest(),
			ExtraData:   block.Extra(),
		},
		BaseFeePerGas: block.BaseFee(),
		L1Origin: &rawdb.L1Origin{
			BlockID:            block.Number(),
			L1BlockHeight:      l1Origin.L1BlockHeight,
			L2BlockHash:        common.Hash{},
			L1BlockHash:        l1Origin.L1BlockHash,
			BuildPayloadArgsID: [8]byte{},
		},
	}
	// Set the chain head to a block with different attributes at first.
	attributes.SuggestedFeeRecipient = common.HexToAddress(RandomHash().Hex())
	attributes.BlockMetadata.Beneficiary = attributes.SuggestedFeeRecipient
	s.forkTo(attributes, block.ParentHash())

	// Set the chain head back to the block we want.
	attributes.SuggestedFeeRecipient = originalCoinbase
	attributes.BlockMetadata.Beneficiary = originalCoinbase
	s.forkTo(attributes, block.ParentHash())

	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(block.Hash(), head.Hash())
}

func (s *ClientTestSuite) SetL1Automine(automine bool) {
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), nil, "evm_setAutomine", automine))
}

func (s *ClientTestSuite) SetIntervalMining(time uint64) {
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), nil, "evm_setIntervalMining", time))
}

func (s *ClientTestSuite) IncreaseTime(time uint64) {
	var result uint64
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), &result, "evm_increaseTime", time))
	s.NotNil(result)
}

func (s *ClientTestSuite) L1Mine() {
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), nil, "evm_mine"))
}

func (s *ClientTestSuite) SetNextBlockTimestamp(time uint64) {
	var result uint64
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), &result, "evm_setNextBlockTimestamp", time))
	s.NotNil(result)
}

func (s *ClientTestSuite) SetL1Snapshot() string {
	var snapshotID string
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), &snapshotID, "evm_snapshot"))
	s.NotEmpty(snapshotID)
	return snapshotID
}

func (s *ClientTestSuite) RevertL1Snapshot(snapshotID string) {
	var revertRes bool
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), &revertRes, "evm_revert", snapshotID))
	s.True(revertRes)
}

func (s *ClientTestSuite) SetBlockTimestampInterval(interval time.Duration) {
	s.Nil(s.RPCClient.L1.CallContext(
		context.Background(),
		nil,
		"anvil_setBlockTimestampInterval",
		interval.Seconds(),
	))
}

func (s *ClientTestSuite) forkTo(attributes *engine.PayloadAttributes, parentHash common.Hash) {
	fcRes, err := s.RPCClient.L2Engine.ForkchoiceUpdate(
		context.Background(),
		&engine.ForkchoiceStateV1{HeadBlockHash: parentHash},
		attributes,
	)
	s.Nil(err)
	s.Equal(engine.VALID, fcRes.PayloadStatus.Status)
	s.NotNil(fcRes.PayloadID)

	payload, err := s.RPCClient.L2Engine.GetPayload(context.Background(), fcRes.PayloadID)
	s.Nil(err)

	execStatus, err := s.RPCClient.L2Engine.NewPayload(context.Background(), payload)
	s.Nil(err)
	s.Equal(engine.VALID, execStatus.Status)

	fc := &engine.ForkchoiceStateV1{HeadBlockHash: payload.BlockHash}

	fcRes, err = s.RPCClient.L2Engine.ForkchoiceUpdate(context.Background(), fc, nil)
	s.Nil(err)
	s.Equal(engine.VALID, fcRes.PayloadStatus.Status)

	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(attributes.L1Origin.BlockID.Uint64(), head.Number.Uint64())

	// For Nethermind: clear txpool state after chain reorg
	// After a reorg, stale txpool caches would reject transaction resubmissions
	// with "already known" or "nonce too low". This clears hash cache, account cache, and pending txs.
	// Pending txs must be cleared because tests resubmit transactions with the same hash/nonce,
	// which would be rejected as "ReplacementNotAllowed" if they remain in the pool.
	if os.Getenv("L2_NODE") == "l2_nmc" {
		var cleared bool
		err := s.RPCClient.L2Engine.CallContext(
			context.Background(),
			&cleared,
			"taikoDebug_clearTxPoolForReorg",
		)
		s.Nil(err)
		s.True(cleared, "TxPool clear failed after forkTo")
	}
}
