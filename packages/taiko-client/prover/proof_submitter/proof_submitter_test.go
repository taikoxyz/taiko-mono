package submitter

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

type ProofSubmitterTestSuite struct {
	suite.Suite
	submitter              *ProofSubmitterPacaya
	proofBuffers           map[proofProducer.ProofType]*proofProducer.ProofBuffer
	batchAggregationNotify chan proofProducer.ProofType
	batchResultCh          chan *proofProducer.BatchProofs
	proofSubmissionCh      chan *proofProducer.ProofRequestBody
}

func (s *ProofSubmitterTestSuite) SetupTest() {
	// Create channels
	s.batchAggregationNotify = make(chan proofProducer.ProofType, 10)
	s.batchResultCh = make(chan *proofProducer.BatchProofs, 10)
	s.proofSubmissionCh = make(chan *proofProducer.ProofRequestBody, 10)

	// Create proof buffers
	s.proofBuffers = map[proofProducer.ProofType]*proofProducer.ProofBuffer{
		proofProducer.ProofTypeSgx: proofProducer.NewProofBuffer(5),
		proofProducer.ProofTypeOp:  proofProducer.NewProofBuffer(5),
	}

	// Create a minimal ProofSubmitterPacaya for testing
	s.submitter = &ProofSubmitterPacaya{
		batchAggregationNotify:    s.batchAggregationNotify,
		proofBuffers:              s.proofBuffers,
		forceBatchProvingInterval: 10 * time.Minute,       // Long interval to avoid interference
		proofPollingInterval:      100 * time.Millisecond, // Short interval for faster tests
	}

	// Initialize monitor context
	s.submitter.monitorCtx, s.submitter.monitorCancel = context.WithCancel(context.Background())
}

func (s *ProofSubmitterTestSuite) TearDownTest() {
	if s.submitter.monitorCancel != nil {
		s.submitter.Stop()
	}
	// Drain channels to avoid goroutine leaks
	select {
	case <-s.batchAggregationNotify:
	default:
	}
}

// Helper function to create test metadata
func (s *ProofSubmitterTestSuite) createTestMetadata(batchID uint64) metadata.TaikoProposalMetaData {
	return &metadata.TaikoDataBlockMetadataPacaya{
		ITaikoInboxBatchInfo: pacayaBindings.ITaikoInboxBatchInfo{
			TxsHash:            [32]byte{byte(batchID + 1)},
			Blocks:             []pacayaBindings.ITaikoInboxBlockParams{},
			BlobHashes:         [][32]byte{{byte(batchID)}},
			ExtraData:          [32]byte{byte(batchID)},
			Coinbase:           common.HexToAddress("0x0987654321098765432109876543210987654321"),
			ProposedIn:         1000,
			BlobCreatedIn:      batchID * 100,
			BlobByteOffset:     0,
			BlobByteSize:       1000,
			GasLimit:           8000000,
			LastBlockId:        batchID * 10,
			LastBlockTimestamp: uint64(time.Now().Unix()),
			AnchorBlockId:      batchID*10 - 1,
			AnchorBlockHash:    [32]byte{byte(batchID)},
			BaseFeeConfig: pacayaBindings.LibSharedDataBaseFeeConfig{
				GasIssuancePerSecond:   1000,
				AdjustmentQuotient:     16,
				SharingPctg:            100,
				MinGasExcess:           0,
				MaxGasIssuancePerBlock: 10000000,
			},
		},
		ITaikoInboxBatchMetadata: pacayaBindings.ITaikoInboxBatchMetadata{
			InfoHash:   [32]byte{byte(batchID + 3)},
			Proposer:   common.HexToAddress("0x1234567890123456789012345678901234567890"),
			BatchId:    batchID,
			ProposedAt: uint64(time.Now().Unix()),
		},
		Log: types.Log{
			BlockNumber: batchID * 100,
			BlockHash:   common.Hash{byte(batchID)},
			TxIndex:     0,
			TxHash:      common.Hash{byte(batchID + 2)},
		},
	}
}

// TestBufferMonitorTimeoutTrigger tests that the monitor triggers aggregation when timeout is reached
func (s *ProofSubmitterTestSuite) TestBufferMonitorTimeoutTrigger() {
	// Create a proof response
	proofResp := &proofProducer.ProofResponse{
		BatchID:   big.NewInt(1),
		ProofType: proofProducer.ProofTypeSgx,
		Meta:      s.createTestMetadata(1),
	}

	// Add proof to buffer
	buffer := s.proofBuffers[proofProducer.ProofTypeSgx]
	_, err := buffer.Write(proofResp)
	s.Require().NoError(err)

	// Start the buffer monitor AFTER adding the proof
	s.submitter.StartBufferMonitor()

	// Wait for at least 2 polling intervals to ensure monitor has had time to check
	// The monitor checks every proofPollingInterval (100ms), and we need to wait for
	// at least one full check cycle after the first item has been in the buffer for
	// proofPollingInterval time.
	time.Sleep(300 * time.Millisecond)

	// Check if aggregation was triggered
	select {
	case proofType := <-s.batchAggregationNotify:
		s.Equal(proofProducer.ProofTypeSgx, proofType)
		s.True(buffer.IsAggregating())
	case <-time.After(200 * time.Millisecond):
		s.Fail("Expected aggregation notification but didn't receive one")
	}
}

// TestBufferMonitorNoTriggerWhenAggregating tests that monitor doesn't trigger when already aggregating
func (s *ProofSubmitterTestSuite) TestBufferMonitorNoTriggerWhenAggregating() {
	// Start the buffer monitor
	s.submitter.StartBufferMonitor()

	// Create a proof response
	proofResp := &proofProducer.ProofResponse{
		BatchID:   big.NewInt(1),
		ProofType: proofProducer.ProofTypeSgx,
		Meta:      s.createTestMetadata(1),
	}

	// Add proof to buffer and mark as aggregating
	buffer := s.proofBuffers[proofProducer.ProofTypeSgx]
	_, err := buffer.Write(proofResp)
	s.Require().NoError(err)
	buffer.MarkAggregating()

	// Wait for more than proofPollingInterval
	time.Sleep(200 * time.Millisecond)

	// Check that no aggregation was triggered
	select {
	case <-s.batchAggregationNotify:
		s.Fail("Should not trigger aggregation when already aggregating")
	case <-time.After(200 * time.Millisecond):
		// Expected behavior - no notification
	}
}

// TestBufferMonitorStopGracefully tests that the monitor stops gracefully
func (s *ProofSubmitterTestSuite) TestBufferMonitorStopGracefully() {
	// Start the buffer monitor
	s.submitter.StartBufferMonitor()

	// Add a proof to buffer
	proofResp := &proofProducer.ProofResponse{
		BatchID:   big.NewInt(1),
		ProofType: proofProducer.ProofTypeSgx,
		Meta:      s.createTestMetadata(1),
	}

	buffer := s.proofBuffers[proofProducer.ProofTypeSgx]
	_, err := buffer.Write(proofResp)
	s.Require().NoError(err)

	// Stop the monitor
	s.submitter.Stop()

	// Wait to ensure monitor has stopped
	time.Sleep(300 * time.Millisecond)

	// No notification should be received after stopping
	select {
	case <-s.batchAggregationNotify:
		s.Fail("Should not receive notifications after stopping")
	default:
		// Expected behavior
	}
}

// TestTryAggregateMaxLengthPriority tests that max length triggers before timeout
func (s *ProofSubmitterTestSuite) TestTryAggregateMaxLengthPriority() {
	// Don't start monitor for this test - we'll test TryAggregate directly
	buffer := s.proofBuffers[proofProducer.ProofTypeSgx]

	// Add proofs up to max length
	for i := 0; i < 5; i++ {
		proofResp := &proofProducer.ProofResponse{
			BatchID:   big.NewInt(int64(i + 1)),
			ProofType: proofProducer.ProofTypeSgx,
			Meta:      s.createTestMetadata(uint64(i + 1)),
		}
		_, err := buffer.Write(proofResp)
		s.Require().NoError(err)
	}

	// TryAggregate should trigger immediately due to max length
	triggered := s.submitter.TryAggregate(buffer, proofProducer.ProofTypeSgx)
	s.True(triggered)

	// Check notification was sent
	select {
	case proofType := <-s.batchAggregationNotify:
		s.Equal(proofProducer.ProofTypeSgx, proofType)
		s.True(buffer.IsAggregating())
	default:
		s.Fail("Expected aggregation notification")
	}
}

// TestTryAggregateTimeoutPriority tests timeout-based aggregation
func (s *ProofSubmitterTestSuite) TestTryAggregateTimeoutPriority() {
	// Set a very short forceBatchProvingInterval for testing
	s.submitter.forceBatchProvingInterval = 50 * time.Millisecond

	buffer := s.proofBuffers[proofProducer.ProofTypeSgx]

	// Add just one proof
	proofResp := &proofProducer.ProofResponse{
		BatchID:   big.NewInt(1),
		ProofType: proofProducer.ProofTypeSgx,
		Meta:      s.createTestMetadata(1),
	}
	_, err := buffer.Write(proofResp)
	s.Require().NoError(err)

	// Initially should not trigger
	triggered := s.submitter.TryAggregate(buffer, proofProducer.ProofTypeSgx)
	s.False(triggered)

	// Wait for timeout
	time.Sleep(60 * time.Millisecond)

	// Now should trigger due to timeout
	triggered = s.submitter.TryAggregate(buffer, proofProducer.ProofTypeSgx)
	s.True(triggered)

	// Check notification
	select {
	case proofType := <-s.batchAggregationNotify:
		s.Equal(proofProducer.ProofTypeSgx, proofType)
		s.True(buffer.IsAggregating())
	default:
		s.Fail("Expected aggregation notification")
	}
}

// TestBufferMonitorWithRealScenario tests a realistic scenario
func (s *ProofSubmitterTestSuite) TestBufferMonitorWithRealScenario() {
	// Use realistic intervals
	s.submitter.proofPollingInterval = 50 * time.Millisecond
	s.submitter.forceBatchProvingInterval = 1 * time.Second

	// Start the buffer monitor
	s.submitter.StartBufferMonitor()

	// Add a single proof
	proofResp := &proofProducer.ProofResponse{
		BatchID:   big.NewInt(1),
		ProofType: proofProducer.ProofTypeSgx,
		Meta:      s.createTestMetadata(1),
	}

	buffer := s.proofBuffers[proofProducer.ProofTypeSgx]
	_, err := buffer.Write(proofResp)
	s.Require().NoError(err)

	// The monitor should trigger aggregation after proofPollingInterval
	// even though buffer is not full
	startTime := time.Now()
	select {
	case proofType := <-s.batchAggregationNotify:
		elapsed := time.Since(startTime)
		s.Equal(proofProducer.ProofTypeSgx, proofType)
		s.True(buffer.IsAggregating())
		// Should trigger within 50-150ms (accounting for timing variations)
		s.True(elapsed >= 50*time.Millisecond && elapsed <= 150*time.Millisecond,
			"Expected trigger between 50-150ms, got %v", elapsed)
	case <-time.After(200 * time.Millisecond):
		s.Fail("Expected aggregation notification within timeout")
	}
}

func TestProofSubmitterTestSuite(t *testing.T) {
	suite.Run(t, new(ProofSubmitterTestSuite))
}
