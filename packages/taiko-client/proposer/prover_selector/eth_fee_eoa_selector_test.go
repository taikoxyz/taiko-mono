package selector

import (
	"context"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type ProverSelectorTestSuite struct {
	testutils.ClientTestSuite
	s             *ETHFeeEOASelector
	proverAddress common.Address
}

func (s *ProverSelectorTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)
	s.proverAddress = crypto.PubkeyToAddress(l1ProverPrivKey.PublicKey)

	protocolConfigs, err := s.RPCClient.TaikoL1.GetConfig(nil)
	s.Nil(err)

	s.s, err = NewETHFeeEOASelector(
		&protocolConfigs,
		s.RPCClient,
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		[]encoding.TierFee{},
		common.Big2,
		[]*url.URL{s.ProverEndpoints[0]},
		32,
		1*time.Minute,
		1*time.Minute,
	)
	s.Nil(err)
}

func (s *ProverSelectorTestSuite) TestProverEndpoints() {
	s.Equal(1, len(s.s.ProverEndpoints()))
}

func (s *ProverSelectorTestSuite) TestProverAssignProver() {
	sig, _, fee, err := s.s.AssignProver(context.Background(), []encoding.TierFee{
		{Tier: encoding.TierOptimisticID, Fee: common.Big256},
		{Tier: encoding.TierSgxID, Fee: common.Big256},
	}, testutils.RandomHash())
	s.NotEmpty(sig)
	s.True(fee.Cmp(common.Big0) > 0)
	s.Nil(err)
}

func TestProverSelectorTestSuite(t *testing.T) {
	suite.Run(t, new(ProverSelectorTestSuite))
}
