package builder

import (
	"context"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	tx, err := s.calldataTxBuilder.BuildLegacy(context.Background(), false, []byte{1})
	s.Nil(err)
	s.Nil(tx.Blobs)

	_, err = s.calldataTxBuilder.BuildOntake(context.Background(), [][]byte{{1}, {2}})
	s.Error(err, "ontake transaction builder is not supported before ontake fork")
}
