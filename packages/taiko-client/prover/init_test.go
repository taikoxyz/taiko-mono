package prover

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

func (s *ProverTestSuite) TestSetApprovalAmount() {
	data, err := encoding.TaikoTokenABI.Pack(
		"approve",
		s.p.cfg.TaikoL1Address,
		common.Big0,
	)
	s.Nil(err)

	_, err = s.p.txmgr.Send(context.Background(), txmgr.TxCandidate{
		TxData: data,
		To:     &s.p.cfg.TaikoTokenAddress,
	})
	s.Nil(err)

	allowance, err := s.p.rpc.TaikoToken.Allowance(nil, s.p.ProverAddress(), s.p.cfg.TaikoL1Address)
	s.Nil(err)

	s.Equal(0, allowance.Cmp(common.Big0))

	// Max that can be approved
	amt, ok := new(big.Int).SetString("58764887351446156758749765621197442946723800609510499661540524634076971270144", 10)
	s.True(ok)

	s.p.cfg.Allowance = amt

	s.Nil(s.p.setApprovalAmount(context.Background(), s.p.cfg.TaikoL1Address))

	allowance, err = s.p.rpc.TaikoToken.Allowance(nil, s.p.ProverAddress(), s.p.cfg.TaikoL1Address)
	s.Nil(err)

	s.Equal(0, amt.Cmp(allowance))
}
