package handler

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
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

func TestProverEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(ProverEventHandlerTestSuite))
}
