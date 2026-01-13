package builder

import (
	"bytes"
	"context"
	"math/big"
	"os"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldataOnly() {
	builder := s.newTestBuilderWithFallback(false, false, nil)
	candidate, err := builder.BuildPacaya(
		context.Background(),
		[]types.Transactions{{}},
		nil,
		nil,
		common.Hash{},
		common.Address{},
	)
	s.Nil(err)
	s.Zero(len(candidate.Blobs))
}

func (s *TransactionBuilderTestSuite) TestBuildCalldataWithBlobAllowed() {
	builder := s.newTestBuilderWithFallback(true, false, nil)
	candidate, err := builder.BuildPacaya(
		context.Background(),
		[]types.Transactions{{}},
		nil,
		nil,
		common.Hash{},
		common.Address{},
	)
	s.Nil(err)
	s.NotZero(len(candidate.Blobs))
}

func (s *TransactionBuilderTestSuite) TestBlobAllowed() {
	builder := s.newTestBuilderWithFallback(false, false, nil)
	s.False(builder.BlobAllow())
	builder = s.newTestBuilderWithFallback(true, false, nil)
	s.True(builder.BlobAllow())
}

func (s *TransactionBuilderTestSuite) TestFallback() {
	// By default, blob fee should be cheaper.
	builder := s.newTestBuilderWithFallback(true, true, nil)
	candidate, err := builder.BuildPacaya(
		context.Background(),
		[]types.Transactions{
			{types.NewTransaction(0, common.MaxAddress, common.Big0, 1024, common.Big0, bytes.Repeat([]byte{0x01}, 1024))},
		},
		nil,
		nil,
		common.Hash{},
		common.Address{},
	)
	s.Nil(err)
	s.NotZero(len(candidate.Blobs))

	// Make blob base fee 1024 Gwei
	builder = s.newTestBuilderWithFallback(true, true, func(
		ctx context.Context,
		backend txmgr.ETHBackend,
	) (*big.Int, *big.Int, *big.Int, error) {
		return common.Big1, common.Big1, new(big.Int).SetUint64(1024 * params.GWei), nil
	})

	candidate, err = builder.BuildPacaya(
		context.Background(),
		[]types.Transactions{
			{types.NewTransaction(0, common.MaxAddress, common.Big0, 1024, common.Big0, bytes.Repeat([]byte{0x01}, 1024))},
		},
		nil,
		nil,
		common.Hash{},
		common.Address{},
	)
	s.Nil(err)
	s.Zero(len(candidate.Blobs))

	// Make block base fee 1024 Gwei too
	builder = s.newTestBuilderWithFallback(true, true, func(
		ctx context.Context,
		backend txmgr.ETHBackend,
	) (*big.Int, *big.Int, *big.Int, error) {
		return new(big.Int).SetUint64(1024 * params.GWei),
			new(big.Int).SetUint64(1024 * params.GWei),
			new(big.Int).SetUint64(1 * params.GWei),
			nil
	})

	candidate, err = builder.BuildPacaya(
		context.Background(),
		[]types.Transactions{
			{types.NewTransaction(0, common.MaxAddress, common.Big0, 1024, common.Big0, bytes.Repeat([]byte{0x01}, 1024))},
		},
		nil,
		nil,
		common.Hash{},
		common.Address{},
	)
	s.Nil(err)
	s.NotZero(len(candidate.Blobs))
}

func (s *TransactionBuilderTestSuite) newTestBuilderWithFallback(
	blobAllowed,
	fallback bool,
	gasPriceEstimatorFn txmgr.GasPriceEstimatorFn,
) *TxBuilderWithFallback {
	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		chainConfig       = config.NewChainConfig(
			s.RPCClient.L2.ChainID,
			s.RPCClient.PacayaClients.ForkHeights.Ontake,
			s.RPCClient.PacayaClients.ForkHeights.Pacaya,
			s.RPCClient.ShastaClients.ForkTime,
		)
	)

	cfg, err := txmgr.NewConfig(txmgr.CLIConfig{
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
	}, log.Root())
	s.Nil(err)

	if gasPriceEstimatorFn != nil {
		cfg.GasPriceEstimatorFn = gasPriceEstimatorFn
	}

	txMgr, err := txmgr.NewSimpleTxManagerFromConfig("tx_builder_test", log.Root(), &metrics.TxMgrMetrics, cfg)
	s.Nil(err)

	txmgrSelector := utils.NewTxMgrSelector(txMgr, nil, nil)

	return NewBuilderWithFallback(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		common.Address{},
		10_000_000,
		chainConfig,
		txmgrSelector,
		true,
		blobAllowed,
		fallback,
	)
}
