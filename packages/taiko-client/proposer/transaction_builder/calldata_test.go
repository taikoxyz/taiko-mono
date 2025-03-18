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
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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

	protocolConfigs, err := rpc.GetProtocolConfigs(s.RPCClient.TaikoL1, nil)
	s.Nil(err)

	chainConfig := config.NewChainConfig(&protocolConfigs)

	s.calldataTxBuilder = NewCalldataTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_L2")),
		common.HexToAddress(os.Getenv("TAIKO_L1")),
		common.Address{},
		0,
		chainConfig,
		false,
	)
	s.blobTxBuiler = NewBlobTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_L1")),
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_L2")),
		10_000_000,
		chainConfig,
		false,
	)
}

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	_, err := s.calldataTxBuilder.BuildOntake(context.Background(), [][]byte{{1}, {2}}, common.Hash{})
	s.Nil(err)
}

func TestTransactionBuilderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionBuilderTestSuite))
}
