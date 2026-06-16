package submitter

import (
	"sync"
	"sync/atomic"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestMarkSGXFallbackOnlyFirstCallerWins(t *testing.T) {
	s := &ProofSubmitter{}
	require.False(t, s.inSGXFallback())
	require.True(t, s.markSGXFallback())  // first caller latches
	require.False(t, s.markSGXFallback()) // already latched
	require.True(t, s.inSGXFallback())

	s.resumeZK()
	require.False(t, s.inSGXFallback())
	require.True(t, s.markSGXFallback()) // can latch again after a resume
}

func TestMarkSGXFallbackConcurrentSingleWinner(t *testing.T) {
	s := &ProofSubmitter{}
	const n = 50
	var (
		wg      sync.WaitGroup
		winners atomic.Int32
	)
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			if s.markSGXFallback() {
				winners.Add(1)
			}
		}()
	}
	wg.Wait()
	require.Equal(t, int32(1), winners.Load())
	require.True(t, s.inSGXFallback())
}
