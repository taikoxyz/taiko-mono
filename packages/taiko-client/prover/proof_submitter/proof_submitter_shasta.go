package submitter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	chainiterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

// ProofSubmitterShasta is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoInbox smart contract.
type ProofSubmitterShasta struct {
	rpc *rpc.Client
	// Proof producers
	baseLevelProofProducer proofProducer.ProofProducer
	zkvmProofProducer      proofProducer.ProofProducer
	// Channels
	batchResultCh          chan *proofProducer.BatchProofs
	batchAggregationNotify chan proofProducer.ProofType
	proofSubmissionCh      chan *proofProducer.ProofRequestBody
	// Utilities
	txBuilder *transaction.ProveBatchesTxBuilder
	sender    *transaction.Sender
	// Addresses
	proverAddress common.Address
	// Batch proof related
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer
	// Intervals
	forceBatchProvingInterval time.Duration
	proofPollingInterval      time.Duration
}

// NewProofSubmitterShasta creates a new Shasta ProofSubmitter instance.
func NewProofSubmitterShasta(
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
) (*ProofSubmitterShasta, error) {
	proofSubmitter := &ProofSubmitterShasta{
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
			senderOpts.ProverSetAddress,
			senderOpts.GasLimit,
		),
		proverAddress:             senderOpts.Txmgr.From(),
		proofPollingInterval:      proofPollingInterval,
		proofBuffers:              proofBuffers,
		forceBatchProvingInterval: forceBatchProvingInterval,
	}

	proofSubmitter.startProofBufferMonitors(ctx)
	return proofSubmitter, nil
}

// StartProofBufferMonitors monitors proof buffers and enforces forced aggregation,
// only be called once during initialization.
func (s *ProofSubmitterShasta) startProofBufferMonitors(ctx context.Context) {
	startProofBufferMonitors(ctx, s.proofBuffers, s.TryAggregate)
}

// RequestProof requests proof for the given Taiko batch.
func (s *ProofSubmitterShasta) RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error {
	// Wait for the last block to be inserted at first.
	header, err := s.rpc.WaitShastaHeader(ctx, meta.Shasta().GetEventData().Id)
	if err != nil {
		return fmt.Errorf(
			"failed to wait for Shasta L2 Header, blockID: %d, error: %w",
			meta.Shasta().GetEventData().Id,
			err,
		)
	}

	lastOriginInLastProposal, err := s.rpc.LastL1OriginInBatchShasta(
		ctx,
		new(big.Int).Sub(meta.Shasta().GetEventData().Id, common.Big1),
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
	lastBlockState, err := s.rpc.ShastaClients.Anchor.GetBlockState(&bind.CallOpts{
		BlockHash: lastOriginInLastProposal.L2BlockHash,
		Context:   ctx,
	})
	if err != nil {
		return err
	}
	proposalID := meta.Shasta().GetEventData().Id
	var (
		opts = &proofProducer.ProofRequestOptionsShasta{
			ProposalID:       proposalID,
			ProverAddress:    s.proverAddress,
			EventL1Hash:      meta.GetRawBlockHash(),
			Headers:          []*types.Header{header},
			L2BlockNums:      l2BlockNums,
			DesignatedProver: meta.GetProposer(), // Designated prover is alwasys the proposer for Shasta.
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
			log.Error("Failed to request proof, context is canceled", "batchID", opts.ProposalID, "error", ctx.Err())
			return nil
		}
		coreState, err := s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
		if err != nil {
			return fmt.Errorf("failed to get Shasta core state: %w", err)
		}
		if coreState.LastFinalizedProposalId.Cmp(meta.Shasta().GetEventData().Id) >= 0 {
			log.Info(
				"Shasta proposal already finalized, skip requesting proof",
				"batchID", meta.Shasta().GetEventData().Id,
				"lastFinalizedProposalID", coreState.LastFinalizedProposalId,
			)
			return nil
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
				if errors.Is(err, proofProducer.ErrProofInProgress) || errors.Is(err, proofProducer.ErrRetry) {
					if time.Since(startAt) > maxProofRequestTimeout {
						log.Warn("Retry timeout exceeded maxProofRequestTimeout, switching to SGX proof as fallback")
						useZK = false
						startAt = time.Now()
					} else {
						return fmt.Errorf("zk proof is WIP, status: %w", err)
					}
				} else {
					log.Debug(
						"ZK proof was not chosen or got unexpected error, attempting to request SGX proof",
						"proposalID", opts.ProposalID,
					)
					useZK = false
					startAt = time.Now()
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
		// Try to add the proof to the buffer.
		proofBuffer, exist := s.proofBuffers[proofResponse.ProofType]
		if !exist {
			return fmt.Errorf("get unexpected proof type from raiko %s", proofResponse.ProofType)
		}
		bufferSize, err := proofBuffer.Write(proofResponse)
		if err != nil {
			return fmt.Errorf(
				"failed to add proof into buffer (id: %d) (current buffer size: %d): %w",
				meta.Shasta().GetEventData().Id,
				bufferSize,
				err,
			)
		}

		log.Info(
			"Proof generated successfully for Shasta batch",
			"proposalID", meta.Shasta().GetEventData().Id,
			"bufferSize", bufferSize,
			"maxBufferSize", proofBuffer.MaxLength,
			"proofType", proofResponse.ProofType,
			"bufferIsAggregating", proofBuffer.IsAggregating(),
			"bufferFirstItemAt", proofBuffer.FirstItemAt(),
		)

		// Try to aggregate the proofs in the buffer.
		s.TryAggregate(proofBuffer, proofResponse.ProofType)

		return nil
	}, backoff.WithContext(backoff.NewConstantBackOff(s.proofPollingInterval), ctx)); err != nil {
		if !errors.Is(err, proofProducer.ErrZkAnyNotDrawn) &&
			!errors.Is(err, proofProducer.ErrProofInProgress) &&
			!errors.Is(err, proofProducer.ErrRetry) {
			log.Error("Failed to request a Shasta proof", "batchID", meta.Shasta().GetEventData().Id, "error", err)
		} else {
			log.Debug("Expected Shasta proof generation error", "error", err, "batchID", meta.Shasta().GetEventData().Id)
		}
		return err
	}

	return nil
}

// BatchSubmitProofs submits the given batch proofs to the Shasta Inbox smart contract.
func (s *ProofSubmitterShasta) BatchSubmitProofs(ctx context.Context, batchProof *proofProducer.BatchProofs) error {
	log.Info(
		"Batch submit Shasta batches proofs",
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

	// Check if there is any invalid batch proofs in the aggregation, if so, we ignore them.
	invalidProposalIDs, err := s.validateBatchProofs(ctx, batchProof)
	if err != nil {
		return fmt.Errorf("failed to validate batch proofs: %w", err)
	}
	if len(invalidProposalIDs) > 0 {
		// If there are invalid proposals in the aggregation, we ignore these proposals.
		log.Warn("Invalid proposals in an aggregation, ignore these proposals", "proposalIDs", invalidProposalIDs)
		proofBuffer.ClearItems(invalidProposalIDs...)
		return ErrInvalidProof
	}
	var (
		latestProvenBlockID = common.Big0
		uint64ProposalIDs   []uint64
		lowestProposalID    uint64
	)
	// Extract all block IDs and the highest block ID in the batches.
	for _, proof := range batchProof.ProofResponses {
		uint64ProposalIDs = append(uint64ProposalIDs, proof.BatchID.Uint64())
		currentLastBlockID := proof.Opts.ShastaOptions().L2BlockNums[len(proof.Opts.ShastaOptions().L2BlockNums)-1]
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

	// Build the Shasta Inbox.prove transaction and send it to the L1 node.
	if err := s.sender.SendBatchProof(
		ctx,
		s.txBuilder.BuildProveBatchesShasta(batchProof),
		batchProof,
	); err != nil {
		proofBuffer.ClearItems(uint64ProposalIDs...)
		// Resend the proof request
		for _, proofResp := range batchProof.ProofResponses {
			s.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: proofResp.Meta}
		}
		if err.Error() == transaction.ErrUnretryableSubmission.Error() {
			return nil
		}
		metrics.ProverAggregationSubmissionErrorCounter.Add(1)
		return err
	}

	proofBuffer.ClearItems(uint64ProposalIDs...)
	metrics.ProverSentProofCounter.Add(float64(len(batchProof.BatchIDs)))
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(latestProvenBlockID.Uint64()))

	return nil
}

// TryAggregate tries to aggregate the proofs in the buffer, if the buffer is full,
// or the forced aggregation interval has passed.
func (s *ProofSubmitterShasta) TryAggregate(buffer *proofProducer.ProofBuffer, proofType proofProducer.ProofType) bool {
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
func (s *ProofSubmitterShasta) AggregateProofsByType(ctx context.Context, proofType proofProducer.ProofType) error {
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
func (s *ProofSubmitterShasta) validateBatchProofs(
	ctx context.Context,
	batchProof *proofProducer.BatchProofs,
) ([]uint64, error) {
	var invalidProposalIDs []uint64

	if len(batchProof.ProofResponses) == 0 {
		return nil, proofProducer.ErrInvalidLength
	}

	// Fetch the latest verified proposal ID.
	coreState, err := s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get Shasta core state: %w", err)
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
			log.Error("A valid proof for this batch has already been submitted", "proposalID", proposalID)
			invalidProposalIDs = append(invalidProposalIDs, proposalID.Uint64())
			continue
		}
	}
	return invalidProposalIDs, nil
}

// ValidateProof checks if the proof's corresponding L1 block is still in the canonical chain and if the
// latest verified head is not ahead of this block proof.
func (s *ProofSubmitterShasta) ValidateProof(
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
func (s *ProofSubmitterShasta) WaitTransitionVerified(ctx context.Context, transitionID *big.Int) error {
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, rpc.DefaultRpcTimeout)
	defer cancel()

	return backoff.Retry(func() error {
		coreState, err := s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
		if err != nil {
			log.Error("Failed to get Shasta core state", "error", err)
			return fmt.Errorf("failed to get Shasta core state: %w", err)
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
			"Waiting for Shasta transition to be verified",
			"transitionID", transitionID,
			"lastFinalizedProposalID", coreState.LastFinalizedProposalId,
		)
		return fmt.Errorf("transition %d not verified yet", transitionID.Uint64())
	}, backoff.WithContext(backoff.NewConstantBackOff(chainiterator.DefaultRetryInterval), ctx))
}
