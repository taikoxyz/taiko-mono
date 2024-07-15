package anchortxvalidator

import (
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type AnchorTxValidatorTestSuite struct {
	testutils.ClientTestSuite
	v *AnchorTxValidator
}

func (s *AnchorTxValidatorTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	validator, err := New(common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")), s.RPCClient.L2.ChainID, s.RPCClient)
	s.Nil(err)
	s.v = validator
}

func (s *AnchorTxValidatorTestSuite) TestValidateAnchorTx() {
	wrongPrivKey, err := crypto.HexToECDSA("2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501200")
	s.Nil(err)

	// 0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38
	goldenTouchPriKey, err := crypto.HexToECDSA(encoding.GoldenTouchPrivKey)
	s.Nil(err)

	// invalid To
	tx := types.NewTransaction(
		0,
		common.BytesToAddress(testutils.RandomBytes(1024)), common.Big0, 0, common.Big0, []byte{},
	)
	s.ErrorContains(s.v.ValidateAnchorTx(tx), "invalid TaikoL2.anchor transaction to")

	// invalid sender
	dynamicFeeTxTx := &types.DynamicFeeTx{
		ChainID:    s.v.rpc.L2.ChainID,
		Nonce:      0,
		GasTipCap:  common.Big1,
		GasFeeCap:  common.Big1,
		Gas:        1,
		To:         &s.v.taikoL2Address,
		Value:      common.Big0,
		Data:       []byte{},
		AccessList: types.AccessList{},
	}

	signer := types.LatestSignerForChainID(s.v.rpc.L2.ChainID)
	tx = types.MustSignNewTx(wrongPrivKey, signer, dynamicFeeTxTx)

	s.ErrorContains(
		s.v.ValidateAnchorTx(tx), "invalid TaikoL2.anchor transaction sender",
	)

	// invalid method selector
	tx = types.MustSignNewTx(goldenTouchPriKey, signer, dynamicFeeTxTx)
	s.ErrorContains(s.v.ValidateAnchorTx(tx), "failed to get TaikoL2.anchor transaction method")
}

func TestAnchorTxValidatorTestSuite(t *testing.T) {
	suite.Run(t, new(AnchorTxValidatorTestSuite))
}
