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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
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
	AddressManager      *bindings.AddressManager
}

func (s *ClientTestSuite) SetupTest() {
	utils.LoadEnv()
	// Default logger
	ver, err := strconv.Atoi(os.Getenv("VERBOSITY"))
	s.Nil(err)
	glogger := log.NewGlogHandler(log.NewTerminalHandler(os.Stdout, true))
	glogger.Verbosity(log.FromLegacyLevel(ver))
	log.SetDefault(log.NewLogger(glogger))

	testAddrPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	s.TestAddrPrivKey = testAddrPrivKey
	s.TestAddr = common.HexToAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	rpcCli, err := rpc.NewClient(context.Background(), &rpc.ClientConfig{
		L1Endpoint:                    os.Getenv("L1_WS"),
		L2Endpoint:                    os.Getenv("L2_WS"),
		TaikoL1Address:                common.HexToAddress(os.Getenv("TAIKO_L1")),
		TaikoL2Address:                common.HexToAddress(os.Getenv("TAIKO_L2")),
		TaikoTokenAddress:             common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		GuardianProverMajorityAddress: common.HexToAddress(os.Getenv("GUARDIAN_PROVER_CONTRACT")),
		GuardianProverMinorityAddress: common.HexToAddress(os.Getenv("GUARDIAN_PROVER_MINORITY")),
		L2EngineEndpoint:              os.Getenv("L2_AUTH"),
		JwtSecret:                     string(jwtSecret),
	})
	s.Nil(err)
	s.RPCClient = rpcCli

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)

	allowance, err := rpcCli.TaikoToken.Allowance(
		nil,
		crypto.PubkeyToAddress(l1ProverPrivKey.PublicKey),
		common.HexToAddress(os.Getenv("TAIKO_L1")),
	)
	s.Nil(err)

	if allowance.Cmp(common.Big0) == 0 {
		ownerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_CONTRACT_OWNER_PRIVATE_KEY")))
		s.Nil(err)

		// Transfer some tokens to provers.
		balance, err := rpcCli.TaikoToken.BalanceOf(nil, crypto.PubkeyToAddress(ownerPrivKey.PublicKey))
		s.Nil(err)
		s.Greater(balance.Cmp(common.Big0), 0)

		opts, err := bind.NewKeyedTransactorWithChainID(ownerPrivKey, rpcCli.L1.ChainID)
		s.Nil(err)
		proverBalance := new(big.Int).Div(balance, common.Big3)
		s.Greater(proverBalance.Cmp(common.Big0), 0)

		_, err = rpcCli.TaikoToken.Transfer(opts, crypto.PubkeyToAddress(l1ProverPrivKey.PublicKey), proverBalance)
		s.Nil(err)

		_, err = rpcCli.TaikoToken.Transfer(
			opts,
			common.HexToAddress(os.Getenv("GUARDIAN_PROVER_MINORITY")),
			new(big.Int).Div(proverBalance, common.Big2),
		)
		s.Nil(err)

		_, err = rpcCli.TaikoToken.Transfer(
			opts,
			common.HexToAddress(os.Getenv("GUARDIAN_PROVER_CONTRACT")),
			new(big.Int).Div(proverBalance, common.Big2),
		)
		s.Nil(err)

		// Increase allowance for TaikoL1
		s.setAllowance(l1ProverPrivKey)
		s.setAllowance(ownerPrivKey)
	}

	s.testnetL1SnapshotID = s.SetL1Snapshot()
}

func (s *ClientTestSuite) setAllowance(key *ecdsa.PrivateKey) {
	t, err := txmgr.NewSimpleTxManager(
		"setAllowance",
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

	decimal, err := s.RPCClient.TaikoToken.Decimals(nil)
	s.Nil(err)

	var (
		bigInt            = new(big.Int).Exp(big.NewInt(1_000_000_000), new(big.Int).SetUint64(uint64(decimal)), nil)
		taikoTokenAddress = common.HexToAddress(os.Getenv("TAIKO_TOKEN"))
	)

	data, err := encoding.TaikoTokenABI.Pack(
		"approve",
		common.HexToAddress(os.Getenv("TAIKO_L1")),
		bigInt,
	)
	s.Nil(err)
	_, err = t.Send(context.Background(), txmgr.TxCandidate{
		TxData: data,
		To:     &taikoTokenAddress,
	})
	s.Nil(err)
}

func (s *ClientTestSuite) TearDownTest() {
	s.RevertL1Snapshot(s.testnetL1SnapshotID)

	s.Nil(rpc.SetHead(context.Background(), s.RPCClient.L2, common.Big0))
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
