package builder

import (
	"net/url"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	selector "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/prover_selector"
)

type TransactionBuilderTestSuite struct {
	testutils.ClientTestSuite
	calldataTxBuilder *CalldataTransactionBuilder
	blobTxBuiler      *BlobTransactionBuilder
}

func (s *TransactionBuilderTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	protocolConfigs, err := s.RPCClient.TaikoL1.GetConfig(nil)
	s.Nil(err)

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	proverSelector, err := selector.NewETHFeeEOASelector(
		&protocolConfigs,
		s.RPCClient,
		crypto.PubkeyToAddress(l1ProposerPrivKey.PublicKey),
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.Address{},
		[]encoding.TierFee{},
		common.Big2,
		[]*url.URL{s.ProverEndpoints[0]},
		32,
	)
	s.Nil(err)
	s.calldataTxBuilder = NewCalldataTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		proverSelector,
		common.Big0,
		common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.Address{},
		0,
		"test",
		false,
	)
	s.blobTxBuiler = NewBlobTransactionBuilder(
		s.RPCClient,
		l1ProposerPrivKey,
		proverSelector,
		common.Big0,
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
		10_000_000,
		"test",
		false,
	)
}

func TestTransactionBuilderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionBuilderTestSuite))
}
