package testutils

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"os"
	"strconv"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

type ClientTestSuite struct {
	suite.Suite
	testnetL1SnapshotID string
	RPCClient           *rpc.Client
	TestAddrPrivKey     *ecdsa.PrivateKey
	TestAddr            common.Address
	AddressManager      *ontakeBindings.AddressManager
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
		TaikoL1Address:              common.HexToAddress(os.Getenv("TAIKO_INBOX")),
		TaikoL2Address:              common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   string(jwtSecret),
	})
	s.Nil(err)
	s.RPCClient = rpcCli

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

	s.testnetL1SnapshotID = s.SetL1Snapshot()
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
		taikoInboxAddress = common.HexToAddress(os.Getenv("TAIKO_INBOX"))
	)

	log.Info("Deposit tokens", "address", crypto.PubkeyToAddress(key.PublicKey).Hex())

	balance, err := s.RPCClient.PacayaClients.TaikoToken.BalanceOf(nil, crypto.PubkeyToAddress(key.PublicKey))
	s.Nil(err)
	s.Greater(balance.Cmp(common.Big0), 0)

	data, err := encoding.TaikoTokenABI.Pack("approve", common.HexToAddress(os.Getenv("TAIKO_INBOX")), balance)
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
	s.Nil(rpc.SetHead(context.Background(), s.RPCClient.L2, common.Big0))
	s.BlobServer.Close()
}

func (s *ClientTestSuite) SetL1Automine(automine bool) {
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), nil, "evm_setAutomine", automine))
}

func (s *ClientTestSuite) IncreaseTime(time uint64) {
	var result uint64
	s.Nil(s.RPCClient.L1.CallContext(context.Background(), &result, "evm_increaseTime", time))
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
