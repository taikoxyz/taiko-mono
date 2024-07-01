package builder

import (
	"context"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	tx, err := s.calldataTxBuilder.Build(context.Background(), []encoding.TierFee{
		{Tier: encoding.TierOptimisticID, Fee: common.Big256},
		{Tier: encoding.TierSgxID, Fee: common.Big256},
		{Tier: encoding.TierSgxAndZkVMID, Fee: common.Big257},
	}, []byte{1}, 0, 0, [32]byte{})
	s.Nil(err)
	s.Nil(tx.Blobs)
}
