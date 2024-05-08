package handler

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

type ProverEventHandlerTestSuite struct {
	testutils.ClientTestSuite
}

func (s *ProverEventHandlerTestSuite) TestGetProvingWindowNotFound() {
	_, err := getProvingWindow(&bindings.TaikoL1ClientBlockProposed{
		Meta: bindings.TaikoDataBlockMetadata{
			MinTier: encoding.TierGuardianMajorityID + 1,
		},
	}, []*rpc.TierProviderTierWithID{})
	s.ErrorIs(err, errTierNotFound)
}

func (s *ProverEventHandlerTestSuite) TestIsBlockVerified() {
	_, slotB, err := s.RPCClient.TaikoL1.GetStateVariables(nil)
	s.Nil(err)

	verified, err := isBlockVerified(
		context.Background(),
		s.RPCClient,
		new(big.Int).SetUint64(slotB.LastVerifiedBlockId),
	)
	s.Nil(err)
	s.True(verified)

	verified, err = isBlockVerified(
		context.Background(),
		s.RPCClient,
		new(big.Int).SetUint64(slotB.LastVerifiedBlockId+1),
	)
	s.Nil(err)
	s.False(verified)
}

func TestProverEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(ProverEventHandlerTestSuite))
}
