package preconfblocks

import (
	"testing"
	"time"

	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type BlockRequestTrackerTestSuite struct {
	suite.Suite
}

func TestBlockRequestTrackerTestSuite(t *testing.T) {
	suite.Run(t, new(BlockRequestTrackerTestSuite))
}

func (s *BlockRequestTrackerTestSuite) TestCooldownExpires() {
	var (
		tracker = newBlockRequestTracker(10 * time.Second)
		hash    = testutils.RandomHash()
		now     = time.Now()
	)

	s.True(tracker.shouldRequest(hash, now), "a hash never requested before is requestable")

	tracker.markPublished(hash, now)
	s.False(tracker.shouldRequest(hash, now.Add(9*time.Second)), "suppressed inside the window")

	// The whole point of the fix: an unanswered request must not suppress the hash forever.
	s.True(tracker.shouldRequest(hash, now.Add(10*time.Second)), "requestable once the window elapses")
}

func (s *BlockRequestTrackerTestSuite) TestSkippedPublishDoesNotConsumeWindow() {
	var (
		tracker = newBlockRequestTracker(10 * time.Second)
		hash    = testutils.RandomHash()
		now     = time.Now()
	)

	// A caller that decides not to publish -- no gossip peers yet, block too old -- consults the
	// tracker but never records, so the next walk retries immediately instead of waiting.
	s.True(tracker.shouldRequest(hash, now))
	s.True(tracker.shouldRequest(hash, now))
}

func (s *BlockRequestTrackerTestSuite) TestAnswerClearsSuppression() {
	var (
		tracker = newBlockRequestTracker(10 * time.Second)
		hash    = testutils.RandomHash()
		now     = time.Now()
	)

	tracker.markPublished(hash, now)
	s.False(tracker.shouldRequest(hash, now))

	tracker.markAnswered(hash)
	s.True(tracker.shouldRequest(hash, now), "an answer retires the request without waiting out the window")
}

func (s *BlockRequestTrackerTestSuite) TestPerHashIsolation() {
	var (
		tracker = newBlockRequestTracker(10 * time.Second)
		first   = testutils.RandomHash()
		second  = testutils.RandomHash()
		now     = time.Now()
	)

	tracker.markPublished(first, now)
	s.False(tracker.shouldRequest(first, now))
	s.True(tracker.shouldRequest(second, now), "the cooldown is per hash")
}

func (s *BlockRequestTrackerTestSuite) TestExpiredEntriesArePruned() {
	var (
		tracker = newBlockRequestTracker(10 * time.Second)
		now     = time.Now()
	)

	for range 32 {
		tracker.markPublished(testutils.RandomHash(), now)
	}
	s.Len(tracker.requestedAt, 32)

	// Any later consultation sweeps the map, so it stays bounded by the number of hashes
	// requested within one window rather than growing for the lifetime of the process.
	s.True(tracker.shouldRequest(testutils.RandomHash(), now.Add(10*time.Second)))
	s.Empty(tracker.requestedAt)
}
