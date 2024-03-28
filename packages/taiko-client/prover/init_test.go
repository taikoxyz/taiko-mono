package prover

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

func (s *ProverTestSuite) TestSetApprovalAmount() {
	opts, err := bind.NewKeyedTransactorWithChainID(s.p.cfg.L1ProverPrivKey, s.p.rpc.L1.ChainID)
	s.Nil(err)

	tx, err := s.p.rpc.TaikoToken.Approve(opts, s.p.cfg.AssignmentHookAddress, common.Big0)
	s.Nil(err)

	_, err = rpc.WaitReceipt(context.Background(), s.p.rpc.L1, tx)
	s.Nil(err)

	allowance, err := s.p.rpc.TaikoToken.Allowance(nil, s.p.ProverAddress(), s.p.cfg.AssignmentHookAddress)
	s.Nil(err)

	s.Equal(0, allowance.Cmp(common.Big0))

	// Max that can be approved
	amt, ok := new(big.Int).SetString("58764887351446156758749765621197442946723800609510499661540524634076971270144", 10)
	s.True(ok)

	s.p.cfg.Allowance = amt

	s.Nil(s.p.setApprovalAmount(context.Background(), s.p.cfg.AssignmentHookAddress))

	allowance, err = s.p.rpc.TaikoToken.Allowance(nil, s.p.ProverAddress(), s.p.cfg.AssignmentHookAddress)
	s.Nil(err)

	s.Equal(0, amt.Cmp(allowance))
}
