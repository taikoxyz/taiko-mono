package builder

import (
	"context"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	tx, err := s.calldataTxBuilder.Build(context.Background(), false, []byte{1})
	s.Nil(err)
	s.Nil(tx.Blobs)
}
