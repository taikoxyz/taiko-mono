package transaction

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v2"
)

func (s *TransactionTestSuite) TestBuildTxs() {
	_, err := s.builder.Build(
		common.Big256,
		&metadata.TaikoDataBlockMetadataOntake{
			TaikoDataBlockMetadataV2: bindings.TaikoDataBlockMetadataV2{
				LivenessBond: big.NewInt(1),
			},
		},
		&bindings.TaikoDataTransition{},
		&bindings.TaikoDataTierProof{},
		1,
	)(&bind.TransactOpts{Nonce: common.Big0, GasLimit: 0, GasTipCap: common.Big0})
	s.Nil(err)
}
