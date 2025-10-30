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
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	shastaIndexer "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/state_indexer"
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
	indexer   *shastaIndexer.Indexer
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
	baseLevelProofProducer proofProducer.ProofProducer,
	zkvmProofProducer proofProducer.ProofProducer,
	batchResultCh chan *proofProducer.BatchProofs,
	batchAggregationNotify chan proofProducer.ProofType,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
	indexer *shastaIndexer.Indexer,
	senderOpts *SenderOptions,
	builder *transaction.ProveBatchesTxBuilder,
	proofPollingInterval time.Duration,
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
	forceBatchProvingInterval time.Duration,
) (*ProofSubmitterShasta, error) {
	return &ProofSubmitterShasta{
		rpc:                    senderOpts.RPCClient,
		baseLevelProofProducer: baseLevelProofProducer,
		zkvmProofProducer:      zkvmProofProducer,
		batchResultCh:          batchResultCh,
		batchAggregationNotify: batchAggregationNotify,
		proofSubmissionCh:      proofSubmissionCh,
		indexer:                indexer,
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
	}, nil
}

// RequestProof requests proof for the given Taiko batch.
func (s *ProofSubmitterShasta) RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error {
	// Wait for the last block to be inserted at first.
	header, err := s.rpc.WaitShastaHeader(ctx, meta.Shasta().GetProposal().Id)
	if err != nil {
		return fmt.Errorf(
			"failed to wait for Shasta L2 Header, blockID: %d, error: %w",
			meta.Shasta().GetProposal().Id,
			err,
		)
	}

	lastOriginInLastProposal, err := s.rpc.LastL1OriginInBatch(
		ctx,
		new(big.Int).Sub(meta.Shasta().GetProposal().Id, common.Big1),
	)
	if err != nil {
		return err
	}
	lastOrigin, err := s.rpc.LastL1OriginInBatch(ctx, meta.Shasta().GetProposal().Id)
	if err != nil {
		return err
	}
	l2BlockLength := lastOrigin.BlockID.Uint64() - lastOriginInLastProposal.BlockID.Uint64()
	l2BlockNums := make([]*big.Int, 0, l2BlockLength)
	for i := uint64(0); i < l2BlockLength; i++ {
		l2BlockNums = append(
			l2BlockNums,
			new(big.Int).SetUint64(i+lastOriginInLastProposal.BlockID.Uint64()+1),
		)
	}
	// Request proof.
	var (
		opts = &proofProducer.ProofRequestOptionsShasta{
			ProposalID:    meta.Shasta().GetProposal().Id,
			ProverAddress: s.proverAddress,
			EventL1Hash:   meta.GetRawBlockHash(),
			Headers:       []*types.Header{header},
			L2BlockNums:   l2BlockNums,
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
		if s.indexer.GetLastCoreState().LastFinalizedProposalId.Cmp(meta.Shasta().GetProposal().Id) >= 0 {
			log.Info(
				"Shasta proposal already finalized, skip requesting proof",
				"batchID", meta.Shasta().GetProposal().Id,
				"lastFinalizedProposalID", s.indexer.GetLastCoreState().LastFinalizedProposalId,
			)
			return nil
		}
		// Check if there is a need to generate proof, if the proof is already submitted and valid, skip
		// the proof submission.
		record := s.indexer.GetTransitionRecordByProposalID(meta.Shasta().GetProposal().Id.Uint64())

		proposalHash, err := s.rpc.GetShastaProposalHash(&bind.CallOpts{Context: ctx}, meta.Shasta().GetProposal().Id)
		if err != nil {
			return fmt.Errorf("failed to get Shasta proposal hash: %w", err)
		}
		parentTransitionHash, err := transaction.BuildParentTransitionHash(
			ctx,
			s.rpc,
			s.indexer,
			meta.Shasta().GetProposal().Id,
		)
		if err != nil {
			return fmt.Errorf("failed to build parent Shasta transition hash: %w", err)
		}
		if record != nil &&
			record.Transition.Checkpoint.BlockHash == header.Hash() &&
			record.Transition.ParentTransitionHash == parentTransitionHash &&
			record.Transition.ProposalHash == proposalHash {
			log.Info(
				"A valid proof has been submitted, skip requesting proof",
				"batchID", meta.Shasta().GetProposal().Id,
				"parent", header.ParentHash,
			)
			return nil
		}

		// If zk proof is enabled, request zk proof first, and check if ZK proof is drawn.
		if s.zkvmProofProducer != nil && useZK {
			if proofResponse, err = s.zkvmProofProducer.RequestProof(
				ctx,
				opts,
				meta.Shasta().GetProposal().Id,
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
				meta.Shasta().GetProposal().Id,
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
				meta.Shasta().GetProposal().Id,
				bufferSize,
				err,
			)
		}

		log.Info(
			"Proof generated successfully for Shasta batch",
			"proposalID", meta.Shasta().GetProposal().Id,
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
			log.Error("Failed to request a Shasta proof", "batchID", meta.Shasta().GetProposal().Id, "error", err)
		} else {
			log.Debug("Expected Shasta proof generation error", "error", err, "batchID", meta.Shasta().GetProposal().Id)
		}
		return err
	}

	s.batchResultCh <- &proofProducer.BatchProofs{
		ProofResponses: []*proofProducer.ProofResponse{proofResponse},
		BatchProof:     proofResponse.Proof,
		BatchIDs:       []*big.Int{meta.Shasta().GetProposal().Id},
		ProofType:      proofResponse.ProofType,
		Verifier:       common.Address{},
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
	// TODO: check if there is valid proof on chain
	var (
		latestProvenBlockID = common.Big0
		uint64ProposalIDs   []uint64
	)
	proofBuffer, exist := s.proofBuffers[batchProof.ProofType]
	if !exist {
		return fmt.Errorf("unexpected proof type from raiko to submit: %s", batchProof.ProofType)
	}
	// Extract all block IDs and the highest block ID in the batches.
	for _, proof := range batchProof.ProofResponses {
		uint64ProposalIDs = append(uint64ProposalIDs, proof.BatchID.Uint64())
		if new(big.Int).SetUint64(proof.Meta.Pacaya().GetLastBlockID()).Cmp(latestProvenBlockID) > 0 {
			latestProvenBlockID = new(big.Int).SetUint64(proof.Meta.Pacaya().GetLastBlockID())
		}
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

	metrics.ProverSentProofCounter.Add(float64(len(batchProof.BatchIDs)))
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(latestProvenBlockID.Uint64()))

	return nil
}

// TryAggregate tries to aggregate the proofs in the buffer, if the buffer is full,
// or the forced aggregation interval has passed.
func (s *ProofSubmitterShasta) TryAggregate(buffer *proofProducer.ProofBuffer, proofType proofProducer.ProofType) bool {
	if !buffer.IsAggregating() &&
		(uint64(buffer.Len()) >= buffer.MaxLength ||
			(buffer.Len() != 0 && time.Since(buffer.FirstItemAt()) > s.forceBatchProvingInterval)) {
		s.batchAggregationNotify <- proofType
		buffer.MarkAggregating()
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
		return err
	}
	return nil
}
