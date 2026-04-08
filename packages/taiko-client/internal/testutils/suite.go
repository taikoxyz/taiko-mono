package testutils

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"net/url"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

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
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
	)

	s.TestAddrPrivKey = testAddrPrivKey
	s.TestAddr = crypto.PubkeyToAddress(testAddrPrivKey.PublicKey)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	rpcCli, err := rpc.NewClient(context.Background(), &rpc.ClientConfig{
		L1Endpoint:         os.Getenv("L1_WS"),
		L2Endpoint:         os.Getenv("L2_WS"),
		InboxAddress:       common.HexToAddress(os.Getenv("INBOX")),
		TaikoAnchorAddress: common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		L2EngineEndpoint:   os.Getenv("L2_AUTH"),
		JwtSecret:          string(jwtSecret),
	})
	s.Nil(err)
	s.RPCClient = rpcCli

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))
	s.ensureActivePreconfOperator()

	// At the beginning of each test, reset the L2 chain to its Shasta-only base state.
	s.once.Do(func() {
		s.resetToBaseBlock(l1ProposerPrivKey)
		s.testnetL1SnapshotID = s.SetL1Snapshot()
	})
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
	return txmgr
}

func (s *ClientTestSuite) KeyFromEnv(envName string) *ecdsa.PrivateKey {
	key, err := crypto.ToECDSA(common.FromHex(os.Getenv(envName)))
	s.Nil(err)
	return key
}

func (s *ClientTestSuite) TearDownTest() {
	s.RevertL1Snapshot(s.testnetL1SnapshotID)
	s.resetToBaseBlock(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY"))
	s.testnetL1SnapshotID = s.SetL1Snapshot()
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

	var proposalID *big.Int
	if len(block.Extra()) >= 7 {
		proposalID = new(big.Int).SetBytes(block.Extra()[1:7])
	}

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
			BatchID:     proposalID,
			ExtraData:   block.Extra(),
		},
		BaseFeePerGas: block.BaseFee(),
		L1Origin: &rawdb.L1Origin{
			BlockID:            block.Number(),
			L1BlockHeight:      l1Origin.L1BlockHeight,
			L2BlockHash:        common.Hash{},
			L1BlockHash:        l1Origin.L1BlockHash,
			BuildPayloadArgsID: l1Origin.BuildPayloadArgsID,
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

func (s *ClientTestSuite) ParseL1HttpURLFromEnv() *url.URL {
	u, err := url.Parse(os.Getenv("L1_HTTP"))
	s.Nil(err)
	return u
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

func (s *ClientTestSuite) ensureActivePreconfOperator() {
	s.NotNil(s.RPCClient.ShastaClients.PreconfWhitelist)

	expected := crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey)
	operator, err := s.RPCClient.GetPreconfWhiteListOperator(nil)
	s.Nil(err)
	if operator == expected {
		return
	}

	info, err := s.RPCClient.ShastaClients.PreconfWhitelist.Operators(nil, expected)
	s.Nil(err)
	s.NotZero(info.ActiveSince)

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	targetTimestamp := uint64(info.ActiveSince)
	if l1Head.Time >= targetTimestamp {
		targetTimestamp = l1Head.Time + 1
	}

	s.SetNextBlockTimestamp(targetTimestamp)
	s.L1Mine()

	operator, err = s.RPCClient.GetPreconfWhiteListOperator(nil)
	s.Nil(err)
	s.Equal(expected, operator)
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
