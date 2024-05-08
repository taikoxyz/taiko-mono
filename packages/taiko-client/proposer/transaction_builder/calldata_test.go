package builder

import (
	"context"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-client/bindings/encoding"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	tx, err := s.calldataTxBuilder.Build(context.Background(), []encoding.TierFee{
		{Tier: encoding.TierOptimisticID, Fee: common.Big256},
		{Tier: encoding.TierSgxID, Fee: common.Big256},
		{Tier: encoding.TierSgxAndZkVMID, Fee: common.Big257},
	}, false, []byte{1})
	s.Nil(err)
	s.Nil(tx.Blobs)
}
