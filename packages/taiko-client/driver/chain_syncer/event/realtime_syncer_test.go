package event

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/fork"
)

type RealTimeSyncerTestSuite struct {
	testutils.ClientTestSuite
	s *Syncer
}

func (s *RealTimeSyncerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	// Use the existing Pacaya RPC client — RealTimeClients will be nil since
	// REALTIME_INBOX is not deployed in the test Docker environment.
	// This lets us test the nil-guard and genesis-height code paths.
	state2, err := state.New(context.Background(), s.RPCClient, fork.RealTime)
	s.Nil(err)

	syncer, err := NewSyncer(
		context.Background(),
		s.RPCClient,
		state2,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 1*time.Hour),
		s.BlobServer.URL(),
		nil,
		fork.RealTime,
	)
	s.Nil(err)
	s.s = syncer
}

func (s *RealTimeSyncerTestSuite) TestCheckReorgRealTimeNilClients() {
	// When RealTimeClients is nil, checkReorgRealTime should return no-reorg.
	s.Nil(s.RPCClient.RealTimeClients)
	result, err := s.s.checkReorgRealTime(context.Background())
	s.Nil(err)
	s.False(result.IsReorged)
}

func (s *RealTimeSyncerTestSuite) TestCheckReorgRealTimeAtGenesis() {
	// At genesis L1 height, checkReorgRealTime should return no-reorg
	// even if RealTimeClients were present. The genesis guard fires first.
	result, err := s.s.checkReorgRealTime(context.Background())
	s.Nil(err)
	s.False(result.IsReorged)
}

func (s *RealTimeSyncerTestSuite) TestLastInsertedProposalHashStartsZero() {
	s.Equal(common.Hash{}, s.s.lastInsertedProposalHash)
}

func (s *RealTimeSyncerTestSuite) TestProcessL1BlocksRealTime() {
	// ProcessL1Blocks should succeed even with no RealTime events.
	s.Nil(s.s.ProcessL1Blocks(context.Background()))
}

func TestRealTimeSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(RealTimeSyncerTestSuite))
}
