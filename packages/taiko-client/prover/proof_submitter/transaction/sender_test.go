package transaction

import (
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type TransactionTestSuite struct {
	testutils.ClientTestSuite
	sender  *Sender
	builder *ProveBatchesTxBuilder
}

func (s *TransactionTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	var l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")

	s.builder = NewProveBatchesTxBuilder(
		s.RPCClient,
		common.HexToAddress(os.Getenv("TAIKO_INBOX")),
		rpc.ZeroAddress,
	)

	txmgr, err := txmgr.NewSimpleTxManager(
		"transactionTestSuite",
		log.Root(),
		new(metrics.NoopTxMetrics),
		txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(l1ProverPrivKey)),
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

	s.sender = NewSender(s.RPCClient, txmgr, txmgr, rpc.ZeroAddress, 0)
}

func TestTxSenderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionTestSuite))
}
