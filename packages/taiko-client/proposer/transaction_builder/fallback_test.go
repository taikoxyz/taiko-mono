package builder

import (
	"context"
	"os"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldataOnly() {
	builder := s.newTestBuilderWithFallback(false, false)
	candidate, err := builder.BuildOntake(context.Background(), [][]byte{{1}, {2}})
	s.Nil(err)
	s.Zero(len(candidate.Blobs))
}

func (s *TransactionBuilderTestSuite) TestBuildCalldataWithBlobAllowed() {
	builder := s.newTestBuilderWithFallback(true, false)
	candidate, err := builder.BuildOntake(context.Background(), [][]byte{{1}, {2}})
	s.Nil(err)
	s.NotZero(len(candidate.Blobs))
}

func (s *TransactionBuilderTestSuite) TestBlobAllowed() {
	builder := s.newTestBuilderWithFallback(false, false)
	s.False(builder.BlobAllow())
	builder = s.newTestBuilderWithFallback(true, false)
	s.True(builder.BlobAllow())
}

func (s *TransactionBuilderTestSuite) newTestBuilderWithFallback(blobAllowed, fallback bool) *TxBuilderWithFallback {
	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	protocolConfigs, err := rpc.GetProtocolConfigs(s.RPCClient.TaikoL1, nil)
	s.Nil(err)

	chainConfig := config.NewChainConfig(&protocolConfigs)

	txMgr, err := txmgr.NewSimpleTxManager(
		"tx_builder_test",
		log.Root(),
		&metrics.TxMgrMetrics,
		txmgr.CLIConfig{
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
	)

	s.Nil(err)

	txmgrSelector := utils.NewTxMgrSelector(txMgr, nil, nil)

	return NewBuilderWithFallback(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_L2")),
		common.HexToAddress(os.Getenv("TAIKO_L1")),
		common.Address{},
		10_000_000,
		"test_fallback_builder",
		chainConfig,
		txmgrSelector,
		true,
		blobAllowed,
		fallback,
	)
}
