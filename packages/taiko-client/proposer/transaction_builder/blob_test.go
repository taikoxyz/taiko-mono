package builder_test

import (
	"bytes"
	"context"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

type TransactionBuilderTestSuite struct {
	testutils.ClientTestSuite
	blobTxBuilder *builder.BlobTransactionBuilder
	txsToPropose  []types.Transactions
}

func (s *TransactionBuilderTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	s.blobTxBuilder = builder.NewBlobTransactionBuilder(
		s.RPCClient,
		common.HexToAddress(os.Getenv("INBOX")),
		common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		10_000_000,
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

func (s *TransactionBuilderTestSuite) TestBuildShastaBlobs() {
	candidate, err := s.blobTxBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
	)
	s.Nil(err)
	s.NotZero(len(candidate.Blobs))
}

func (s *TransactionBuilderTestSuite) TestSplitToBlobs() {
	blobs, err := builder.SplitToBlobs(bytes.Repeat([]byte{0x01}, 2*1024))
	s.Nil(err)
	s.NotZero(len(blobs))
}

func TestTransactionBuilderTestSuite(t *testing.T) {
	suite.Run(t, new(TransactionBuilderTestSuite))
}
