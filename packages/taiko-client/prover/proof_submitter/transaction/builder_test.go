package transaction

import (
	"context"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-client/bindings"
)

func (s *TransactionTestSuite) TestBuildTxs() {
	_, err := s.builder.Build(
		common.Big256,
		&bindings.TaikoDataBlockMetadata{},
		&bindings.TaikoDataTransition{},
		&bindings.TaikoDataTierProof{},
		false,
	)(s.sender.innerSender.GetOpts(context.Background()))
	s.NotNil(err)

	_, err = s.builder.Build(
		common.Big256,
		&bindings.TaikoDataBlockMetadata{},
		&bindings.TaikoDataTransition{},
		&bindings.TaikoDataTierProof{},
		true,
	)(s.sender.innerSender.GetOpts(context.Background()))
	s.NotNil(err)
}
