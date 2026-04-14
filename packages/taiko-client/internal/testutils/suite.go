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
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
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
	switch os.Getenv("L2_NODE") {
	case "l2_geth":
		s.Nil(rpc.SetHead(context.Background(), s.RPCClient.L2, headNum))
		return
	case "l2_reth", "l2_nmc":
		s.setHeadByForkchoiceAncestor(headNum)
		return
	}
}

func (s *ClientTestSuite) setHeadByForkchoiceAncestor(headNum *big.Int) {
	ctx := context.Background()

	block, err := s.RPCClient.L2.BlockByNumber(ctx, headNum)
	s.Nil(err)

	l1Origin, err := s.RPCClient.L2.L1OriginByID(ctx, block.Number())
	s.Nil(err)

	fcRes, err := s.RPCClient.L2Engine.ForkchoiceUpdate(
		ctx,
		&engine.ForkchoiceStateV1{
			HeadBlockHash:      block.Hash(),
			SafeBlockHash:      block.Hash(),
			FinalizedBlockHash: block.Hash(),
		},
		nil,
	)
	s.Nil(err)
	s.Equal(engine.VALID, fcRes.PayloadStatus.Status)

	head, err := s.RPCClient.L2.HeaderByNumber(ctx, nil)
	s.Nil(err)
	s.Equal(block.Hash(), head.Hash())

	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(ctx, l1Origin.BlockID)
	s.Nil(err)

	s.clearTxPoolAfterReorg(ctx, "SetHead ancestor unwind")
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

	s.clearTxPoolAfterReorg(context.Background(), "forkTo")
}

func (s *ClientTestSuite) clearTxPoolAfterReorg(ctx context.Context, source string) {
	// Tests resubmit transactions with the same hash/nonce after resetting the canonical head,
	// so stale pool entries would otherwise be rejected as already known or nonce-conflicting.
	switch os.Getenv("L2_NODE") {
	case "l2_nmc":
		var cleared bool
		err := s.RPCClient.L2Engine.CallContext(
			ctx,
			&cleared,
			"taikoDebug_clearTxPoolForReorg",
		)
		s.Nil(err)
		s.True(cleared, "TxPool clear failed after "+source)
	case "l2_reth":
		var cleared uint64
		err := s.RPCClient.L2.CallContext(
			ctx,
			&cleared,
			"admin_clearTxpool",
		)
		s.Nil(err)
	}
}
