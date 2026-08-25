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

func (s *BlockRequestTrackerTestSuite) TestDroppedResponseLifecycle() {
	// The whole point of the cooldown, end to end at the tracker level: a request goes out, the
	// response is dropped, and the next re-drive -- whether an inbound payload or the retry
	// ticker -- publishes again once the window has elapsed, rather than being suppressed for the
	// lifetime of the process.
	var (
		tracker = newBlockRequestTracker(blockRequestCooldown)
		missing = testutils.RandomHash()
		now     = time.Now()
		publish = func(at time.Time) bool {
			if !tracker.shouldRequest(missing, at) {
				return false
			}
			tracker.markPublished(missing, at)
			return true
		}
	)

	s.True(publish(now), "first request goes out")

	// Every re-drive inside the window is suppressed, however many arrive.
	for _, elapsed := range []time.Duration{0, time.Second, blockRequestCooldown - time.Nanosecond} {
		s.False(publish(now.Add(elapsed)))
	}

	// The response never arrives; the ticker fires past the window and the request is retried.
	retriedAt := now.Add(blockRequestCooldown)
	s.True(publish(retriedAt), "an unanswered request is retried, not suppressed forever")

	// This time it is answered, which retires the request rather than making the next one wait.
	tracker.markAnswered(missing)
	s.True(tracker.shouldRequest(missing, retriedAt))
}
