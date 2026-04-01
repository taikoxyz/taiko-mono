package handler

import (
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type ProverEventHandlerTestSuite struct {
	testutils.ClientTestSuite
}

func (s *ProverEventHandlerTestSuite) TestIsProvingWindowExpiredShasta_Remaining() {
	configs, err := s.RPCClient.GetProtocolConfigsShasta(nil)
	s.Nil(err)

	pw := configs.ProvingWindow.Uint64()
	now := uint64(time.Now().Unix())

	notExpiredTs := int64(now + pw - 5)
	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:       common.Big1,
			Proposer: common.Address{},
		},
		uint64(notExpiredTs),
	)

	expired, _, remaining, err := IsProvingWindowExpiredShasta(s.RPCClient, meta)
	s.Nil(err)
	s.False(expired)
	s.True(remaining > 0)

	expiredTs := int64(now - pw - 5)
	metaExpired := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:       common.Big2,
			Proposer: common.Address{},
		},
		uint64(expiredTs),
	)

	expired2, _, remaining2, err := IsProvingWindowExpiredShasta(s.RPCClient, metaExpired)
	s.Nil(err)
	s.True(expired2)
	s.Equal(time.Duration(0), remaining2)
}

func TestProverEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(ProverEventHandlerTestSuite))
}
