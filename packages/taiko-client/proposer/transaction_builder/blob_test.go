package builder

import (
	"github.com/ethereum-optimism/optimism/op-service/eth"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

func (s *TransactionBuilderTestSuite) TestBuildBlob() {
	tx, err := s.blobTxBuiler.buildOntake([][]byte{{1}})
	s.Nil(err)
	s.Equal(1, len(tx.Blobs))

	tx, err = s.blobTxBuiler.buildOntake([][]byte{{1}, {2}})
	s.Nil(err)
	s.Equal(1, len(tx.Blobs))

	tx, err = s.blobTxBuiler.buildOntake([][]byte{testutils.RandomBytes(eth.MaxBlobDataSize), {2}})
	s.Nil(err)
	s.Equal(2, len(tx.Blobs))

	tx, err = s.blobTxBuiler.buildOntake([][]byte{
		testutils.RandomBytes(eth.MaxBlobDataSize), {2}, {3}, testutils.RandomBytes(eth.MaxBlobDataSize)},
	)
	s.Nil(err)
	s.Equal(3, len(tx.Blobs))
}
