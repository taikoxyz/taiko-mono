package builder

import (
	"context"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	tx, err := s.calldataTxBuilder.Build(context.Background(), []byte{1}, 0, 0, [32]byte{})
	s.Nil(err)
	s.Nil(tx.Blobs)
}
