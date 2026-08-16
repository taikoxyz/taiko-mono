package state

import (
	"context"
	"math/big"
	"sync"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"
)

type errSignalingContext struct {
	context.Context
	errCalled chan struct{}
	once      sync.Once
}

func (c *errSignalingContext) Err() error {
	err := c.Context.Err()
	c.once.Do(func() { close(c.errCalled) })
	return err
}

type ProverSharedStateTestSuite struct {
	suite.Suite
	state *SharedState
}

func (s *ProverSharedStateTestSuite) SetupTest() {
	s.state = New()
}

func (s *ProverSharedStateTestSuite) TestLastHandledShastaProposalID() {
	newLastHandledBlockID := uint64(1024)
	s.NotEqual(newLastHandledBlockID, s.state.GetLastHandledProposalID())
	s.state.SetLastHandledProposalID(newLastHandledBlockID)
	s.Equal(newLastHandledBlockID, s.state.GetLastHandledProposalID())
}

func (s *ProverSharedStateTestSuite) TestL1Current() {
	newL1Current := &types.Header{Number: common.Big256}
	s.NotEqual(newL1Current, s.state.GetL1Current())
	s.state.SetL1Current(newL1Current)
	s.Equal(newL1Current.Hash(), s.state.GetL1Current().Hash())
}

func (s *ProverSharedStateTestSuite) TestLowerLastHandledProposalID() {
	s.state.SetLastHandledProposalID(10)

	s.state.LowerLastHandledProposalID(5)
	s.Equal(uint64(5), s.state.GetLastHandledProposalID())

	// Lowering to a value above the current cursor must not advance it.
	s.state.LowerLastHandledProposalID(8)
	s.Equal(uint64(5), s.state.GetLastHandledProposalID())

	s.state.LowerLastHandledProposalID(5)
	s.Equal(uint64(5), s.state.GetLastHandledProposalID())
}

func (s *ProverSharedStateTestSuite) TestLowerL1Current() {
	s.state.SetL1Current(&types.Header{Number: big.NewInt(100)})

	s.state.LowerL1Current(&types.Header{Number: big.NewInt(90)})
	s.Equal(uint64(90), s.state.GetL1Current().Number.Uint64())

	// Lowering to a header above the current cursor must not advance it.
	s.state.LowerL1Current(&types.Header{Number: big.NewInt(95)})
	s.Equal(uint64(90), s.state.GetL1Current().Number.Uint64())
}

func (s *ProverSharedStateTestSuite) TestLowerL1CurrentUnset() {
	s.Nil(s.state.GetL1Current())

	s.state.LowerL1Current(&types.Header{Number: big.NewInt(42)})
	s.Equal(uint64(42), s.state.GetL1Current().Number.Uint64())
}

func (s *ProverSharedStateTestSuite) TestRollbackProposalCursor() {
	s.state.SetLastHandledProposalID(10)
	s.state.SetL1Current(&types.Header{Number: big.NewInt(100)})

	s.True(s.state.RollbackProposalCursor(context.Background(), 5, &types.Header{Number: big.NewInt(90)}))
	s.Equal(uint64(5), s.state.GetLastHandledProposalID())
	s.Equal(uint64(90), s.state.GetL1Current().Number.Uint64())

	// Rolling back to values above the current cursors must not advance them.
	s.True(s.state.RollbackProposalCursor(context.Background(), 8, &types.Header{Number: big.NewInt(95)}))
	s.Equal(uint64(5), s.state.GetLastHandledProposalID())
	s.Equal(uint64(90), s.state.GetL1Current().Number.Uint64())
}

func (s *ProverSharedStateTestSuite) TestRollbackProposalCursorCanceledWhileWaitingForLock() {
	s.state.SetLastHandledProposalID(10)
	s.state.SetL1Current(&types.Header{Number: big.NewInt(100)})

	lockAcquired := make(chan struct{})
	releaseLock := make(chan struct{})
	lockDone := make(chan error, 1)
	go func() {
		lockDone <- s.state.WithProposalCursor(func() error {
			close(lockAcquired)
			<-releaseLock
			return nil
		})
	}()
	<-lockAcquired

	ctx, cancel := context.WithCancel(context.Background())
	instrumentedCtx := &errSignalingContext{Context: ctx, errCalled: make(chan struct{})}
	rollbackDone := make(chan bool, 1)
	go func() {
		rollbackDone <- s.state.RollbackProposalCursor(
			instrumentedCtx,
			5,
			&types.Header{Number: big.NewInt(90)},
		)
	}()

	<-instrumentedCtx.errCalled
	cancel()
	close(releaseLock)

	s.NoError(<-lockDone)
	s.False(<-rollbackDone)
	s.Equal(uint64(10), s.state.GetLastHandledProposalID())
	s.Equal(uint64(100), s.state.GetL1Current().Number.Uint64())
}

func (s *ProverSharedStateTestSuite) TestWithProposalCursorLocksDuringScan() {
	s.state.SetLastHandledProposalID(10)
	s.state.SetL1Current(&types.Header{Number: big.NewInt(100)})

	s.NoError(s.state.WithProposalCursor(func() error {
		acquired := s.state.proposalCursorMu.TryLock()
		if acquired {
			s.state.proposalCursorMu.Unlock()
		}
		s.False(acquired, "proposal cursor lock was not held during the scan")

		s.state.SetLastHandledProposalID(20)
		s.state.SetL1Current(&types.Header{Number: big.NewInt(200)})
		return nil
	}))

	s.Equal(uint64(20), s.state.GetLastHandledProposalID())
	s.Equal(uint64(200), s.state.GetL1Current().Number.Uint64())
}

func TestProverSharedStateTestSuite(t *testing.T) {
	suite.Run(t, new(ProverSharedStateTestSuite))
}
