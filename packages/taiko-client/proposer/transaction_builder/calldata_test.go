package builder

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
)

type TransactionBuilderTestSuite struct {
	testutils.ClientTestSuite
	calldataTxBuilder *CalldataTransactionBuilder
	blobTxBuiler      *BlobTransactionBuilder
}

func (s *TransactionBuilderTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	chainConfig := config.NewChainConfig(
		s.RPCClient.L2.ChainID,
		s.RPCClient.OntakeClients.ForkHeight,
		s.RPCClient.PacayaClients.ForkHeight,
	)

	s.calldataTxBuilder = NewCalldataTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		common.HexToAddress(os.Getenv("TAIKO_INBOX")),
		common.Address{},
		0,
		chainConfig,
		false,
	)
	s.blobTxBuiler = NewBlobTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_INBOX")),
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		10_000_000,
		chainConfig,
		false,
	)
}

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	_, err := s.calldataTxBuilder.BuildOntake(context.Background(), [][]byte{{1}, {2}})
	s.Nil(err)
}

func TestTransactionBuilderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionBuilderTestSuite))
}
