package submitter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	chainiterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

var ErrProposalOutOfAllowedRange = errors.New("proposalID out of allowed proving range")

// SenderOptions is the options for the transaction sender.
type SenderOptions struct {
	RPCClient    *rpc.Client
	Txmgr        txmgr.TxManager
	PrivateTxmgr txmgr.TxManager
	GasLimit     uint64
}

// ProofSubmitter is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoInbox smart contract.
type ProofSubmitter struct {
	rpc *rpc.Client
	// Proof producers
	baseLevelProofProducer proofProducer.ProofProducer
	zkvmProofProducer      proofProducer.ProofProducer
	// Channels
	batchResultCh          chan *proofProducer.BatchProofs
	batchAggregationNotify chan proofProducer.ProofType
	proofSubmissionCh      chan *proofProducer.ProofRequestBody
	flushCacheNotify       chan proofProducer.ProofType
	// Utilities
	txBuilder *transaction.ProveBatchesTxBuilder
	sender    *transaction.Sender
	// Addresses
	proverAddress common.Address
	// Batch proof related
	proofBuffers   map[proofProducer.ProofType]*proofProducer.ProofBuffer
	proofCacheMaps map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]
	// Intervals
	forceBatchProvingInterval time.Duration
	proofPollingInterval      time.Duration
	proposalWindowSize        *big.Int
}

// NewProofSubmitter creates a new ProofSubmitter instance.
func NewProofSubmitter(
	ctx context.Context,
	baseLevelProofProducer proofProducer.ProofProducer,
	zkvmProofProducer proofProducer.ProofProducer,
	batchResultCh chan *proofProducer.BatchProofs,
	batchAggregationNotify chan proofProducer.ProofType,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
	senderOpts *SenderOptions,
	builder *transaction.ProveBatchesTxBuilder,
	proofPollingInterval time.Duration,
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
	forceBatchProvingInterval time.Duration,
	proofCacheMaps map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse],
	flushCacheNotify chan proofProducer.ProofType,
	proposalWindowSize *big.Int,
) (*ProofSubmitter, error) {
	proofSubmitter := &ProofSubmitter{
		rpc:                    senderOpts.RPCClient,
		baseLevelProofProducer: baseLevelProofProducer,
		zkvmProofProducer:      zkvmProofProducer,
		batchResultCh:          batchResultCh,
		batchAggregationNotify: batchAggregationNotify,
		proofSubmissionCh:      proofSubmissionCh,
		txBuilder:              builder,
		sender: transaction.NewSender(
			senderOpts.RPCClient,
			senderOpts.Txmgr,
			senderOpts.PrivateTxmgr,
			senderOpts.GasLimit,
		),
		proverAddress:             senderOpts.Txmgr.From(),
		proofPollingInterval:      proofPollingInterval,
		proofBuffers:              proofBuffers,
		forceBatchProvingInterval: forceBatchProvingInterval,
		proofCacheMaps:            proofCacheMaps,
		flushCacheNotify:          flushCacheNotify,
		proposalWindowSize:        proposalWindowSize,
	}

	proofSubmitter.startBackgroundWorkers(ctx)
	return proofSubmitter, nil
}

// startBackgroundWorkers launches goroutines that monitor proof buffers and
// prune cached proofs; should only run once during initialization.
func (s *ProofSubmitter) startBackgroundWorkers(ctx context.Context) {
	log.Info("Starting proof submitter background workers", "interval", monitorInterval)
	startProofBufferMonitors(ctx, s.proofBuffers, s.TryAggregate)
	startCacheCleanUpAndFlush(ctx, s.rpc, s.proofCacheMaps, s.flushCacheNotify)
}

// RequestProof requests proof for the given Taiko batch.
func (s *ProofSubmitter) RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error {
	proposalID := meta.GetProposalID()

	// Wait for the last block to be inserted at first.
	header, err := s.rpc.WaitProposalHeader(ctx, proposalID)
	if err != nil {
		return fmt.Errorf("failed to wait for L2 header, blockID: %d, error: %w", proposalID, err)
	}

	lastOriginInLastProposal, err := s.rpc.LastL1OriginInProposal(
		ctx,
		new(big.Int).Sub(proposalID, common.Big1),
	)
	if err != nil {
		return err
	}
	l2BlockLength := header.Number.Uint64() - lastOriginInLastProposal.BlockID.Uint64()
	l2BlockNums := make([]*big.Int, 0, l2BlockLength)
	for i := uint64(0); i < l2BlockLength; i++ {
		l2BlockNums = append(
			l2BlockNums,
			new(big.Int).SetUint64(i+lastOriginInLastProposal.BlockID.Uint64()+1),
		)
	}
	// Request proof.
	blockStateOpts := &bind.CallOpts{Context: ctx}
	if lastOriginInLastProposal.BlockID.Cmp(common.Big0) == 0 {
		blockStateOpts.BlockNumber = common.Big0
	} else {
		blockStateOpts.BlockHash = lastOriginInLastProposal.L2BlockHash
	}
	lastBlockState, err := s.rpc.ShastaClients.Anchor.GetBlockState(blockStateOpts)
	if err != nil {
		return err
	}
	var (
		opts = &proofProducer.ProposalProofRequestOptions{
			ProposalID:       proposalID,
			ProverAddress:    s.proverAddress,
			EventL1Hash:      meta.GetRawBlockHash(),
			Headers:          []*types.Header{header},
			L2BlockNums:      l2BlockNums,
			DesignatedProver: meta.GetProposer(), // Designated prover is always the proposer for Shasta.
			Checkpoint: &proofProducer.Checkpoint{
				BlockNumber: header.Number,
				BlockHash:   header.Hash(),
				StateRoot:   header.Root,
			},
			LastAnchorBlockNumber: lastBlockState.AnchorBlockNumber,
		}
		startAt       = time.Now()
		proofResponse *proofProducer.ProofResponse
		useZK         = true
	)

	// Send the generated proof.
	if err := backoff.Retry(func() error {
		if ctx.Err() != nil {
			log.Error("Failed to request proof, context is canceled", "proposalID", opts.ProposalID, "error", ctx.Err())
			return nil
		}
		coreState, err := s.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
		if err != nil {
			return fmt.Errorf("failed to get core state: %w", err)
		}
		lastFinalizedProposalID := coreState.LastFinalizedProposalId
		fromID := new(big.Int).Add(lastFinalizedProposalID, common.Big1)
		if fromID.Cmp(proposalID) > 0 {
			log.Info(
				"Proposal already finalized, skip requesting proof",
				"proposalID", proposalID,
				"lastFinalizedProposalID", lastFinalizedProposalID,
			)
			return nil
		}
		if s.isProposalOutOfRange(proposalID, lastFinalizedProposalID) {
			log.Info(
				"Proof request deferred: ErrProposalOutOfAllowedRange",
				"proposalID", proposalID,
				"lastFinalizedProposalID", lastFinalizedProposalID,
				"proposalWindowSize", s.proposalWindowSize,
				"error", ErrProposalOutOfAllowedRange,
			)
			return ErrProposalOutOfAllowedRange
		}

		// If zk proof is enabled, request zk proof first, and check if ZK proof is drawn.
		if s.zkvmProofProducer != nil && useZK {
			if proofResponse, err = s.zkvmProofProducer.RequestProof(
				ctx,
				opts,
				meta.Shasta().GetEventData().Id,
				meta,
				startAt,
			); err != nil {
				if time.Since(startAt) > maxProofRequestTimeout {
					log.Warn("Retry timeout exceeded maxProofRequestTimeout, switching to SGX proof as fallback")
					useZK = false
					startAt = time.Now()
				} else {
					if errors.Is(err, proofProducer.ErrZkAnyNotDrawn) {
						log.Debug(
							"ZK proof was not chosen, attempting to request SGX proof",
							"proposalID", opts.ProposalID,
							"err", err,
						)
						useZK = false
						startAt = time.Now()
					}
					log.Debug("Got error, retrying", "err", err)
					return err
				}
			}
		}
		// If zk proof is not enabled or zk proof is not drawn, request the base level proof.
		if proofResponse == nil {
			if proofResponse, err = s.baseLevelProofProducer.RequestProof(
				ctx,
				opts,
				meta.Shasta().GetEventData().Id,
				meta,
				startAt,
			); err != nil {
				if time.Since(startAt) > maxProofRequestTimeout {
					log.Warn("WARN: Proof generation taking too long, please investigate")
				}
				return fmt.Errorf("failed to request base proof, error: %w", err)
			}
		}
		return s.handleProofResponse(meta, fromID, proofResponse)
	}, backoff.WithContext(backoff.NewConstantBackOff(s.proofPollingInterval), ctx)); err != nil {
		if !errors.Is(err, proofProducer.ErrZkAnyNotDrawn) &&
			!errors.Is(err, proofProducer.ErrProofInProgress) &&
			!errors.Is(err, proofProducer.ErrRetry) &&
			!errors.Is(err, ErrProposalOutOfAllowedRange) {
			log.Error("Failed to request a proof", "proposalID", meta.Shasta().GetEventData().Id, "error", err)
		} else {
			log.Debug("Expected proof generation error", "error", err, "proposalID", meta.Shasta().GetEventData().Id)
		}
		return err
	}

	return nil
}

// isProposalOutOfRange checks whether proposalID is outside the configured proving window.
// Valid range is [lastFinalizedProposalID + 1, lastFinalizedProposalID + proposalWindowSize].
func (s *ProofSubmitter) isProposalOutOfRange(
	proposalID *big.Int,
	lastFinalizedProposalID *big.Int,
) bool {
	if s.proposalWindowSize == nil || s.proposalWindowSize.Cmp(common.Big1) < 0 {
		return false
	}

	maxAllowedProposalID := new(big.Int).Add(lastFinalizedProposalID, s.proposalWindowSize)
	return proposalID.Cmp(maxAllowedProposalID) > 0 || proposalID.Cmp(lastFinalizedProposalID) <= 0
}

// handleProofResponse routes a new proof into either the sequential buffer or cache.
func (s *ProofSubmitter) handleProofResponse(
	meta metadata.TaikoProposalMetaData,
	fromID *big.Int,
	proofResponse *proofProducer.ProofResponse,
) error {
	if fromID == nil {
		return fmt.Errorf("fromID cannot be nil when handling proof response")
	}
	proofBuffer, exist := s.proofBuffers[proofResponse.ProofType]
	if !exist {
		return fmt.Errorf("get unexpected proof type from raiko %s", proofResponse.ProofType)
	}
	cacheMap, exist := s.proofCacheMaps[proofResponse.ProofType]
	if !exist {
		return fmt.Errorf("get unexpected proof type from raiko %s", proofResponse.ProofType)
	}

	toBeInsertedID := fromID
	if proofBuffer.LastInsertID() > 0 {
		toBeInsertedID = new(big.Int).SetUint64(proofBuffer.LastInsertID() + 1)
	}
	proposalID := meta.GetProposalID()
	if proposalID.Cmp(toBeInsertedID) == 0 {
		bufferSize, err := proofBuffer.Write(proofResponse)
		if err != nil {
			return fmt.Errorf(
				"failed to add proof into buffer (id: %d) (current buffer size: %d): %w",
				proposalID,
				bufferSize,
				err,
			)
		}
		// Try to aggregate the proofs in the buffer.
		s.TryAggregate(proofBuffer, proofResponse.ProofType)
	} else {
		cacheMap.Set(proposalID.String(), proofResponse)
		tryFlushCache(s.flushCacheNotify, proofResponse.ProofType)
	}
	log.Info(
		"Proof generated successfully for proposal",
		"proposalID", proposalID,
		"bufferSize", proofBuffer.Len(),
		"maxBufferSize", proofBuffer.MaxLength,
		"proofType", proofResponse.ProofType,
		"bufferIsAggregating", proofBuffer.IsAggregating(),
		"bufferFirstItemAt", proofBuffer.FirstItemAt(),
	)
	return nil
}

// BatchSubmitProofs submits the given aggregated proposal proofs to the inbox contract.
func (s *ProofSubmitter) BatchSubmitProofs(ctx context.Context, batchProof *proofProducer.BatchProofs) error {
	log.Info(
		"Submit aggregated proposal proofs",
		"proof", common.Bytes2Hex(batchProof.BatchProof),
		"size", len(batchProof.ProofResponses),
		"firstID", batchProof.BatchIDs[0],
		"lastID", batchProof.BatchIDs[len(batchProof.BatchIDs)-1],
		"proofType", batchProof.ProofType,
	)
	proofBuffer, exist := s.proofBuffers[batchProof.ProofType]
	if !exist {
		return fmt.Errorf("unexpected proof type from raiko to submit: %s", batchProof.ProofType)
	}

	// Check if there are any invalid proposal proofs in the aggregation, and ignore them.
	invalidProposalIDs, err := s.validateBatchProofs(ctx, batchProof)
	if err != nil {
		return fmt.Errorf("failed to validate proposal proofs: %w", err)
	}
	if len(invalidProposalIDs) > 0 {
		// If there are invalid proposals in the aggregation, we ignore these proposals.
		log.Warn("Invalid proposals in an aggregation, ignore these proposals", "proposalIDs", invalidProposalIDs)
		proofBuffer.ClearItems(invalidProposalIDs...)
		return ErrInvalidProof
	}
	var (
		latestProvenBlockID = common.Big0
		lowestProposalID    uint64
	)
	// Extract all proposal IDs and the highest proven block ID in the aggregation.
	for _, proof := range batchProof.ProofResponses {
		blockNums := proof.Opts.ProposalOptions().L2BlockNums
		currentLastBlockID := blockNums[len(blockNums)-1]
		if currentLastBlockID.Cmp(latestProvenBlockID) > 0 {
			latestProvenBlockID = currentLastBlockID
		}
		if lowestProposalID == 0 || proof.BatchID.Uint64() < lowestProposalID {
			lowestProposalID = proof.BatchID.Uint64()
		}
	}
	// Wait for the parent transition to be proven before the submission.
	if err := s.WaitTransitionVerified(
		ctx,
		new(big.Int).Sub(new(big.Int).SetUint64(lowestProposalID), common.Big1),
	); err != nil {
		return fmt.Errorf("failed to wait parent transition verified: %w", err)
	}

	// Build the inbox prove transaction and send it to the L1 node.
	if err := s.sender.SendBatchProof(
		ctx,
		s.txBuilder.BuildProveBatchesShasta(ctx, batchProof),
		batchProof,
	); err != nil {
		metrics.ProverAggregationSubmissionErrorCounter.Add(1)
		return err
	}

	metrics.ProverSentProofCounter.Add(float64(len(batchProof.BatchIDs)))
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(latestProvenBlockID.Uint64()))

	return nil
}

// ClearProofBuffers removes the submitted proof items from the proof buffer.
func (s *ProofSubmitter) ClearProofBuffers(batchProof *proofProducer.BatchProofs, resend bool) error {
	if err := clearProofBufferItems(s.proofBuffers, batchProof); err != nil {
		return err
	}
	if resend {
		// Resend the proof request
		for _, proofResp := range batchProof.ProofResponses {
			s.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: proofResp.Meta}
		}
	}
	return nil
}

// TryAggregate tries to aggregate the proofs in the buffer, if the buffer is full,
// or the forced aggregation interval has passed.
func (s *ProofSubmitter) TryAggregate(buffer *proofProducer.ProofBuffer, proofType proofProducer.ProofType) bool {
	// Check conditions first (without locking)
	if uint64(buffer.Len()) < buffer.MaxLength &&
		(buffer.Len() == 0 || time.Since(buffer.FirstItemAt()) <= s.forceBatchProvingInterval) {
		return false
	}

	if buffer.MarkAggregatingIfNot() { // Returns true if successfully marked
		s.batchAggregationNotify <- proofType
		return true
	}
	return false
}

// AggregateProofsByType aggregates proofs of the specified type and submits them in a batch.
func (s *ProofSubmitter) AggregateProofsByType(ctx context.Context, proofType proofProducer.ProofType) error {
	proofBuffer, exist := s.proofBuffers[proofType]
	if !exist {
		return fmt.Errorf("failed to get expected proof type: %s", proofType)
	}
	var producer proofProducer.ProofProducer
	// nolint:exhaustive
	// We deliberately handle only known proof types and catch others in default case
	switch proofType {
	case proofProducer.ProofTypeOp, proofProducer.ProofTypeSgx:
		producer = s.baseLevelProofProducer
	case proofProducer.ProofTypeZKR0, proofProducer.ProofTypeZKSP1:
		producer = s.zkvmProofProducer
	default:
		return fmt.Errorf("unknown proof type: %s", proofType)
	}
	startAt := time.Now()
	buffer, err := proofBuffer.ReadAll()
	if err != nil {
		return fmt.Errorf("failed to read proof from buffer: %w", err)
	}
	// If the buffer is empty, skip the aggregation.
	if len(buffer) == 0 {
		log.Debug("Buffer is empty now, skip aggregating")
		return nil
	}
	if err := backoff.Retry(
		func() error {
			result, err := producer.Aggregate(ctx, buffer, startAt)
			if err != nil {
				if errors.Is(err, proofProducer.ErrProofInProgress) || errors.Is(err, proofProducer.ErrRetry) {
					log.Debug(
						"Aggregating proofs",
						"status", err,
						"batchSize", len(buffer),
						"firstID", buffer[0].BatchID,
						"lastID", buffer[len(buffer)-1].BatchID,
						"proofType", proofType,
					)
				} else {
					log.Error("Failed to request proof aggregation", "err", err)
				}
				return err
			}
			s.batchResultCh <- result
			return nil
		},
		backoff.WithContext(backoff.NewConstantBackOff(s.proofPollingInterval), ctx),
	); err != nil {
		log.Error("Aggregate proof error", "error", err)
		batchIDs := make([]uint64, 0, len(buffer))
		for _, proof := range buffer {
			if proof.BatchID == nil {
				continue
			}
			batchIDs = append(batchIDs, proof.BatchID.Uint64())
		}
		proofBuffer.ClearItems(batchIDs...)
		return err
	}
	return nil
}

// validateBatchProofs validates the batch proofs before submitting them to the L1 chain,
// returns the invalid proposal IDs.
func (s *ProofSubmitter) validateBatchProofs(
	ctx context.Context,
	batchProof *proofProducer.BatchProofs,
) ([]uint64, error) {
	var invalidProposalIDs []uint64

	if len(batchProof.ProofResponses) == 0 {
		return nil, proofProducer.ErrInvalidLength
	}

	// Fetch the latest verified proposal ID.
	coreState, err := s.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get core state: %w", err)
	}
	latestVerifiedID := coreState.LastFinalizedProposalId

	// Check if any batch in this aggregation is already submitted and valid,
	// if so, we skip this batch.
	for _, proof := range batchProof.ProofResponses {
		// Check if this proof is still needed to be submitted.
		ok, err := s.ValidateProof(ctx, proof, latestVerifiedID)
		if err != nil {
			return nil, err
		}
		proposalID := proof.BatchID
		if !ok {
			log.Error("A valid proof for this proposal has already been submitted", "proposalID", proposalID)
			invalidProposalIDs = append(invalidProposalIDs, proposalID.Uint64())
			continue
		}
	}
	return invalidProposalIDs, nil
}

// ValidateProof checks if the proof's corresponding L1 block is still in the canonical chain and if the
// latest verified head is not ahead of this block proof.
func (s *ProofSubmitter) ValidateProof(
	ctx context.Context,
	proofResponse *proofProducer.ProofResponse,
	latestVerifiedID *big.Int,
) (bool, error) {
	// 1. Check if the corresponding L1 block is still in the canonical chain.
	l1Header, err := s.rpc.L1.HeaderByNumber(ctx, proofResponse.Meta.GetRawBlockHeight())
	if err != nil {
		log.Warn(
			"Failed to fetch L1 block",
			"proposalID", proofResponse.BatchID,
			"l1Height", proofResponse.Meta.GetRawBlockHeight(),
			"error", err,
		)
		return false, err
	}
	if l1Header.Hash() != proofResponse.Opts.GetRawBlockHash() {
		log.Warn(
			"Reorg detected, skip the current proof submission",
			"proposalID", proofResponse.BatchID,
			"l1Height", proofResponse.Meta.GetRawBlockHeight(),
			"l1HashOld", proofResponse.Opts.GetRawBlockHash(),
			"l1HashNew", l1Header.Hash(),
		)
		return false, nil
	}

	if latestVerifiedID.Cmp(proofResponse.BatchID) >= 0 {
		log.Info(
			"Proposal is already finalized, skip current proof submission",
			"proposalID", proofResponse.BatchID,
			"latestVerifiedID", latestVerifiedID,
		)
		return false, nil
	}

	return true, nil
}

// WaitTransitionVerified waits until the given transition ID is verified on L1.
func (s *ProofSubmitter) WaitTransitionVerified(ctx context.Context, transitionID *big.Int) error {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, rpc.DefaultRpcTimeout)
	defer cancel()

	return backoff.Retry(func() error {
		coreState, err := s.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
		if err != nil {
			log.Error("Failed to get core state", "error", err)
			return fmt.Errorf("failed to get core state: %w", err)
		}
		if coreState.LastFinalizedProposalId.Cmp(transitionID) >= 0 {
			log.Info(
				"Transition verified",
				"lastFinalizedProposalID", coreState.LastFinalizedProposalId,
				"transitionID", transitionID,
			)
			return nil
		}
		log.Info(
			"Waiting for transition to be verified",
			"transitionID", transitionID,
			"lastFinalizedProposalID", coreState.LastFinalizedProposalId,
		)
		return fmt.Errorf("transition %d not verified yet", transitionID.Uint64())
	}, backoff.WithContext(backoff.NewConstantBackOff(chainiterator.DefaultRetryInterval), ctx))
}

func (s *ProofSubmitter) FlushCache(ctx context.Context, proofType proofProducer.ProofType) error {
	buffer, exist := s.proofBuffers[proofType]
	if !exist {
		return fmt.Errorf("failed to get buffer with expected proof type: %s", proofType)
	}
	cacheMap, exist := s.proofCacheMaps[proofType]
	if !exist {
		return fmt.Errorf("failed to get cache map with expected proof type: %s", proofType)
	}
	coreState, err := s.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get core state: %w", err)
	}
	fromID := new(big.Int).Add(coreState.LastFinalizedProposalId, common.Big1)
	if buffer.LastInsertID() > 0 {
		fromID = new(big.Int).SetUint64(buffer.LastInsertID() + 1)
	}
	toID := new(big.Int).Add(fromID, new(big.Int).SetUint64(buffer.AvailableCapacity()))
	if err := flushProofCacheRange(fromID, toID, buffer, cacheMap); err != nil {
		if !errors.Is(err, ErrCacheNotFound) {
			log.Error(
				"Failed to flush proof cache range",
				"error", err,
				"fromID", fromID,
				"toID", toID,
			)
			return fmt.Errorf("failed to flush proof cache range: %w", err)
		}
	}
	s.TryAggregate(buffer, proofType)
	return nil
}
