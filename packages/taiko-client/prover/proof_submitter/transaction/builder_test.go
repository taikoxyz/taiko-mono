package transaction

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

func (s *TransactionTestSuite) TestBuildTxs() {
	_, err := s.builder.Build(
		common.Big256,
		&metadata.TaikoDataBlockMetadataLegacy{},
		&bindings.TaikoDataTransition{},
		&bindings.TaikoDataTierProof{},
		1,
	)(&bind.TransactOpts{Nonce: common.Big0, GasLimit: 0, GasTipCap: common.Big0})
	s.Nil(err)
}
