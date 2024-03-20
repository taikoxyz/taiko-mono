package builder

import (
	"context"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-client/pkg/sender"
	selector "github.com/taikoxyz/taiko-client/proposer/prover_selector"
)

type TransactionBuilderTestSuite struct {
	testutils.ClientTestSuite
	calldataTxBuilder *CalldataTransactionBuilder
	blobTxBuiler      *BlobTransactionBuilder
	sender            *sender.Sender
}

func (s *TransactionBuilderTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	protocolConfigs, err := s.RPCClient.TaikoL1.GetConfig(nil)
	s.Nil(err)

	proverSelector, err := selector.NewETHFeeEOASelector(
		&protocolConfigs,
		s.RPCClient,
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		[]encoding.TierFee{},
		common.Big2,
		[]*url.URL{s.ProverEndpoints[0]},
		32,
		1*time.Minute,
		1*time.Minute,
	)
	s.Nil(err)
	s.calldataTxBuilder = NewCalldataTransactionBuilder(
		s.RPCClient,
		proverSelector,
		common.Big0,
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		"test",
	)
	s.blobTxBuiler = NewBlobTransactionBuilder(
		s.RPCClient,
		proverSelector,
		common.Big0,
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
		common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		"test",
	)

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	s.sender, err = sender.NewSender(context.Background(), &sender.Config{
		MaxGasFee:      20000000000,
		GasGrowthRate:  50,
		MaxRetrys:      0,
		GasLimit:       2000000,
		MaxWaitingTime: time.Second * 10,
	}, s.RPCClient.L1, l1ProposerPrivKey)
	s.Nil(err)
}

func (s *TransactionBuilderTestSuite) TestGetParentMetaHash() {
	metahash, err := getParentMetaHash(context.Background(), s.RPCClient)
	s.Nil(err)
	s.Empty(metahash)
}

func TestTransactionBuilderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionBuilderTestSuite))
}
