package transaction

import (
	"context"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

func (s *TransactionTestSuite) TestGetProveBlocksTxOpts() {
	optsL1, err := getProveBlocksTxOpts(context.Background(), s.RPCClient.L1, s.RPCClient.L1.ChainID, s.TestAddrPrivKey)
	s.Nil(err)
	s.Greater(optsL1.GasTipCap.Uint64(), uint64(0))

	optsL2, err := getProveBlocksTxOpts(context.Background(), s.RPCClient.L2, s.RPCClient.L2.ChainID, s.TestAddrPrivKey)
	s.Nil(err)
	s.Greater(optsL2.GasTipCap.Uint64(), uint64(0))
}

func (s *TransactionTestSuite) TestBuildTxs() {
	_, err := s.builder.Build(
		context.Background(),
		common.Big256,
		&bindings.TaikoDataBlockMetadata{},
		&bindings.TaikoDataTransition{},
		&bindings.TaikoDataTierProof{},
		false,
	)(common.Big256)
	s.NotNil(err)

	_, err = s.builder.Build(
		context.Background(),
		common.Big256,
		&bindings.TaikoDataBlockMetadata{},
		&bindings.TaikoDataTransition{},
		&bindings.TaikoDataTierProof{},
		true,
	)(common.Big256)
	s.NotNil(err)
}
