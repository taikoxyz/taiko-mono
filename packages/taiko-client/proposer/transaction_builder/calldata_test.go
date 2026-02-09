package builder

import (
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
)

type TransactionBuilderTestSuite struct {
	testutils.ClientTestSuite
	calldataTxBuilder *CalldataTransactionBuilder
	blobTxBuilder     *BlobTransactionBuilder
	txsToPropose      []types.Transactions
}

func (s *TransactionBuilderTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		chainConfig       = config.NewChainConfig(
			s.RPCClient.L2.ChainID,
			s.RPCClient.PacayaClients.ForkHeights.Ontake,
			s.RPCClient.PacayaClients.ForkHeights.Pacaya,
			s.RPCClient.ShastaClients.ForkTime,
		)
	)

	s.calldataTxBuilder = NewCalldataTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		common.Address{},
		0,
		chainConfig,
		false,
	)
	s.blobTxBuilder = NewBlobTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		common.HexToAddress(os.Getenv("PROVER_SET")),
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		10_000_000,
		chainConfig,
		false,
	)

	for i := 0; i < 100; i++ {
		s.txsToPropose = append(s.txsToPropose, []*types.Transaction{types.NewTransaction(
			uint64(i),
			common.Address{},
			common.Big0,
			0,
			common.Big0,
			nil,
		)})
	}
}

func TestTransactionBuilderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionBuilderTestSuite))
}
