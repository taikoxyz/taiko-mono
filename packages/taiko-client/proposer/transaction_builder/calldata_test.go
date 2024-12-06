package builder

import (
	"context"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	_, err := s.calldataTxBuilder.BuildOntake(context.Background(), [][]byte{{1}, {2}})
	s.Nil(err)
}
