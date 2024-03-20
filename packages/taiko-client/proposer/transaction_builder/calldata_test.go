package builder

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
)

func (s *TransactionBuilderTestSuite) TestBuildCalldata() {
	tx, err := s.calldataTxBuilder.Build(context.Background(), []encoding.TierFee{
		{Tier: encoding.TierOptimisticID, Fee: common.Big256},
		{Tier: encoding.TierSgxID, Fee: common.Big256},
		{Tier: encoding.TierSgxAndZkVMID, Fee: common.Big257},
	}, s.sender.GetOpts(context.Background()), false, []byte{1})
	s.Nil(err)
	s.Equal(types.DynamicFeeTxType, int(tx.Type()))
}
