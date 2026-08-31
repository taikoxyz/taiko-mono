package beaconsync

import (
	"testing"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type BeaconSyncProgressTrackerTestSuite struct {
	testutils.ClientTestSuite
	t *SyncProgressTracker
}

func (s *BeaconSyncProgressTrackerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	s.t = NewSyncProgressTracker(s.RPCClient.L2)
}

func (s *BeaconSyncProgressTrackerTestSuite) TestClearMeta() {
	s.t.triggered = true
	s.t.ClearMeta()
	s.False(s.t.triggered)
}

func (s *BeaconSyncProgressTrackerTestSuite) TestHeadChanged() {
	s.True(s.t.NeedReSync(common.Big256))
	s.t.triggered = true
	s.True(s.t.NeedReSync(common.Big256))
}

func (s *BeaconSyncProgressTrackerTestSuite) TestTriggered() {
	s.False(s.t.Triggered())
}

func (s *BeaconSyncProgressTrackerTestSuite) TestLastSyncedBlockID() {
	s.Nil(s.t.LastSyncedBlockID())
	s.t.lastSyncedBlockID = common.Big1
	s.Equal(common.Big1.Uint64(), s.t.LastSyncedBlockID().Uint64())
}

func (s *BeaconSyncProgressTrackerTestSuite) TestLastSyncedVerifiedBlockHash() {
	s.Equal(
		common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000"),
		s.t.LastSyncedBlockHash(),
	)
	randomHash := testutils.RandomHash()
	s.t.lastSyncedBlockHash = randomHash
	s.Equal(randomHash, s.t.LastSyncedBlockHash())
}

func TestLastSyncProgress(t *testing.T) {
	tracker := NewSyncProgressTracker(nil)
	require.Nil(t, tracker.LastSyncProgress())

	progress := &ethereum.SyncProgress{CurrentBlock: 1, HighestBlock: 2}
	tracker.mutex.Lock()
	tracker.lastSyncProgress = progress
	tracker.mutex.Unlock()

	require.Equal(t, progress, tracker.LastSyncProgress())
}

func TestBeaconSyncProgressTrackerTestSuite(t *testing.T) {
	suite.Run(t, new(BeaconSyncProgressTrackerTestSuite))
}
