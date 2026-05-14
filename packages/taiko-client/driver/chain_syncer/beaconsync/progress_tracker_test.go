package beaconsync

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type BeaconSyncProgressTrackerTestSuite struct {
	testutils.ClientTestSuite
	t *SyncProgressTracker
}

func (s *BeaconSyncProgressTrackerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	s.t = NewSyncProgressTracker(s.RPCClient.L2, 30*time.Second)
}

func (s *BeaconSyncProgressTrackerTestSuite) TestSyncProgressed() {
	s.False(syncProgressed(nil, &ethereum.SyncProgress{}), nil)
	s.False(syncProgressed(&ethereum.SyncProgress{}, &ethereum.SyncProgress{}))

	// Block
	s.True(syncProgressed(&ethereum.SyncProgress{CurrentBlock: 0}, &ethereum.SyncProgress{CurrentBlock: 1}))
	s.False(syncProgressed(&ethereum.SyncProgress{CurrentBlock: 0}, &ethereum.SyncProgress{CurrentBlock: 0}))
	s.False(syncProgressed(&ethereum.SyncProgress{CurrentBlock: 1}, &ethereum.SyncProgress{CurrentBlock: 1}))

	// Fast sync fields
	s.True(syncProgressed(&ethereum.SyncProgress{PulledStates: 0}, &ethereum.SyncProgress{PulledStates: 1}))

	// Snap sync fields
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedAccounts: 0}, &ethereum.SyncProgress{SyncedAccounts: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedAccountBytes: 0}, &ethereum.SyncProgress{SyncedAccountBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedBytecodes: 0}, &ethereum.SyncProgress{SyncedBytecodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedBytecodeBytes: 0}, &ethereum.SyncProgress{SyncedBytecodeBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedStorage: 0}, &ethereum.SyncProgress{SyncedStorage: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{SyncedStorageBytes: 0}, &ethereum.SyncProgress{SyncedStorageBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedTrienodes: 0}, &ethereum.SyncProgress{HealedTrienodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedTrienodeBytes: 0}, &ethereum.SyncProgress{HealedTrienodeBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedBytecodes: 0}, &ethereum.SyncProgress{HealedBytecodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealedBytecodeBytes: 0}, &ethereum.SyncProgress{HealedBytecodeBytes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealingTrienodes: 0}, &ethereum.SyncProgress{HealingTrienodes: 1}))
	s.True(syncProgressed(&ethereum.SyncProgress{HealingBytecode: 0}, &ethereum.SyncProgress{HealingBytecode: 1}))
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

func (s *BeaconSyncProgressTrackerTestSuite) TestOutOfSync() {
	s.False(s.t.OutOfSync())
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

// TestTrack_MarksFinishedAndFlipsOutOfSync_WhenEEReportsSyncedAtPivot is a regression
// test for the `--p2p.sync` plateau: once the EE reports `eth_syncing: false` AND its
// head is at or past the last beacon pivot we asked it to sync to, the tracker must
// mark the beacon sync `finished = true` (so `needNewBeaconSyncTriggered` short-circuits
// on the next tick) AND set `outOfSync = true` (so `SetUpEventSync` uses the EE's live
// head instead of a `blockIDToSync=0` that would reset L1Current to genesis). Together
// these flip the syncer to event-sync immediately, instead of waiting out the full
// `--p2p.syncTimeout` (default 1h). Without both flips, the driver wedges in a
// TriggerBeaconSync→no-op loop until the timeout expires.
func (s *BeaconSyncProgressTrackerTestSuite) TestTrack_MarksFinishedAndFlipsOutOfSync_WhenEEReportsSyncedAtPivot() {
	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Simulate: we've previously triggered a beacon-sync to the current L2 head.
	// The EE has caught up (head matches lastSyncedBlockID) and reports `eth_syncing: false`.
	s.t.triggered = true
	s.t.lastSyncedBlockID = head.Number
	s.t.lastSyncedBlockHash = head.Hash()
	s.t.lastProgressedTime = time.Now()
	s.False(s.t.outOfSync)
	s.False(s.t.finished)

	s.t.track(context.Background())

	s.True(s.t.outOfSync, "track() must set outOfSync=true once the EE has caught the beacon pivot")
	s.True(s.t.finished, "track() must mark the beacon sync finished once the EE has caught the beacon pivot")
}

// TestTrack_PreservesLastSyncProgress_OnRpcError protects against the
// codex P2 issue: a transient RPC failure during `eth_syncing` must not
// clobber the previously-observed `lastSyncProgress`, or the next
// successful poll cannot detect that the engine advanced, and the
// tracker can spuriously hit the `--p2p.syncTimeout`.
func (s *BeaconSyncProgressTrackerTestSuite) TestTrack_PreservesLastSyncProgress_OnRpcError() {
	prev := &ethereum.SyncProgress{CurrentBlock: 100, HighestBlock: 200}
	s.t.triggered = true
	s.t.lastSyncedBlockID = common.Big256
	s.t.lastSyncProgress = prev

	// Cancel before calling track() so the RPC fails immediately.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	s.t.track(ctx)

	s.Equal(prev, s.t.lastSyncProgress, "RPC error path must not overwrite lastSyncProgress")
}

func TestBeaconSyncProgressTrackerTestSuite(t *testing.T) {
	suite.Run(t, new(BeaconSyncProgressTrackerTestSuite))
}
