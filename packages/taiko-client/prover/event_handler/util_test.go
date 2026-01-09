package handler

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type ProverEventHandlerTestSuite struct {
	testutils.ClientTestSuite
}

func (s *ProverEventHandlerTestSuite) TestIsBatchVerified() {
	state2, err := s.RPCClient.PacayaClients.TaikoInbox.GetStats2(nil)
	s.Nil(err)

	batch, err := s.RPCClient.PacayaClients.TaikoInbox.GetBatch(nil, state2.LastVerifiedBatchId)
	s.Nil(err)

	verified, err := isBatchVerified(context.Background(), s.RPCClient, new(big.Int).SetUint64(batch.BatchId))
	s.Nil(err)
	s.True(verified)

	verified, err = isBatchVerified(context.Background(), s.RPCClient, new(big.Int).SetUint64(batch.BatchId+1))
	s.Nil(err)
	s.False(verified)
}

func (s *ProverEventHandlerTestSuite) TestIsProvingWindowExpired() {
	protocolConfigs, err := s.RPCClient.GetProtocolConfigs(nil)
	s.Nil(err)

	provingWindow, err := protocolConfigs.ProvingWindow()
	s.Nil(err)

	timestamp := time.Now().Unix()

	expired, expiredAt, _, err := IsProvingWindowExpired(
		s.RPCClient,
		metadata.NewTaikoDataBlockMetadataPacaya(
			&pacayaBindings.TaikoInboxClientBatchProposed{
				Meta: pacayaBindings.ITaikoInboxBatchMetadata{ProposedAt: uint64(timestamp)},
			},
		),
	)
	s.Nil(err)
	s.False(expired)
	s.Equal(time.Unix(int64(uint64(timestamp)+uint64(provingWindow.Seconds())), 0), expiredAt)
}

func (s *ProverEventHandlerTestSuite) TestIsProvingWindowExpired_PacayaExpiredZeroRemaining() {
	protocolConfigs, err := s.RPCClient.GetProtocolConfigs(nil)
	s.Nil(err)

	provingWindow, err := protocolConfigs.ProvingWindow()
	s.Nil(err)

	now := time.Now().Unix()
	pastTs := now - int64(provingWindow.Seconds()) - 5

	expired, _, remaining, err := IsProvingWindowExpired(
		s.RPCClient,
		metadata.NewTaikoDataBlockMetadataPacaya(
			&pacayaBindings.TaikoInboxClientBatchProposed{
				Meta: pacayaBindings.ITaikoInboxBatchMetadata{ProposedAt: uint64(pastTs)},
			},
		),
	)
	s.Nil(err)
	s.True(expired)
	s.Equal(time.Duration(0), remaining)
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
