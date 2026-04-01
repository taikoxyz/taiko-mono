package transaction

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
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
		common.HexToAddress(os.Getenv("INBOX")),
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

	s.sender = NewSender(s.RPCClient, txmgr, txmgr, 0)
}

func (s *TransactionTestSuite) TestValidateProof() {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	coreState, err := s.RPCClient.GetCoreStateShasta(nil)
	s.Nil(err)

	proposalID := new(big.Int).Add(coreState.LastFinalizedProposalId, common.Big1)
	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:       proposalID,
			Proposer: common.Address{},
			Raw: types.Log{
				BlockNumber: l1Head.Number.Uint64(),
				BlockHash:   l1Head.Hash(),
			},
		},
		l1Head.Time,
	)

	ok, err := s.sender.ValidateProof(
		context.Background(),
		&producer.ProofResponse{
			BatchID:   proposalID,
			Meta:      meta,
			Proof:     testutils.RandomBytes(100),
			Opts:      &producer.ProofRequestOptionsShasta{EventL1Hash: l1Head.Hash()},
			ProofType: producer.ProofTypeOp,
		},
		coreState.LastFinalizedProposalId,
	)
	s.Nil(err)
	s.True(ok)
}

func TestTxSenderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionTestSuite))
}
