package submitter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	validator "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/anchor_tx_validator"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

var (
	MaxNumSupportedZkTypes    = 2
	MaxNumSupportedProofTypes = 4
)

// ProofSubmitterPacaya is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoL1 smart contract.
type ProofSubmitterPacaya struct {
	rpc                    *rpc.Client
	baseLevelProofProducer proofProducer.ProofProducer
	zkvmProofProducer      proofProducer.ProofProducer
	resultCh               chan *proofProducer.ProofResponse
	batchResultCh          chan *proofProducer.BatchProofs
	aggregationNotify      chan uint16
	batchAggregationNotify chan proofProducer.ProofType
	anchorValidator        *validator.AnchorTxValidator
	txBuilder              *transaction.ProveBlockTxBuilder
	sender                 *transaction.Sender
	proverAddress          common.Address
	proverSetAddress       common.Address
	taikoAnchorAddress     common.Address
	// Batch proof related
	proofBuffers              map[proofProducer.ProofType]*proofProducer.ProofBuffer
	forceBatchProvingInterval time.Duration
}

// NewProofSubmitter creates a new ProofSubmitter instance.
func NewProofSubmitterPacaya(
	rpcClient *rpc.Client,
	baseLevelProver proofProducer.ProofProducer,
	zkvmProofProducer proofProducer.ProofProducer,
	resultCh chan *proofProducer.ProofResponse,
	batchResultCh chan *proofProducer.BatchProofs,
	aggregationNotify chan uint16,
	batchAggregationNotify chan proofProducer.ProofType,
	proverSetAddress common.Address,
	taikoAnchorAddress common.Address,
	gasLimit uint64,
	txmgr txmgr.TxManager,
	privateTxmgr txmgr.TxManager,
	builder *transaction.ProveBlockTxBuilder,
	proofBuffers map[proofProducer.ProofType]*proofProducer.ProofBuffer,
	forceBatchProvingInterval time.Duration,
) (*ProofSubmitterPacaya, error) {
	anchorValidator, err := validator.New(taikoAnchorAddress, rpcClient.L2.ChainID, rpcClient)
	if err != nil {
		return nil, err
	}

	return &ProofSubmitterPacaya{
		rpc:                       rpcClient,
		baseLevelProofProducer:    baseLevelProver,
		zkvmProofProducer:         zkvmProofProducer,
		resultCh:                  resultCh,
		batchResultCh:             batchResultCh,
		aggregationNotify:         aggregationNotify,
		batchAggregationNotify:    batchAggregationNotify,
		anchorValidator:           anchorValidator,
		txBuilder:                 builder,
		sender:                    transaction.NewSender(rpcClient, txmgr, privateTxmgr, proverSetAddress, gasLimit),
		proverAddress:             txmgr.From(),
		proverSetAddress:          proverSetAddress,
		taikoAnchorAddress:        taikoAnchorAddress,
		proofBuffers:              proofBuffers,
		forceBatchProvingInterval: forceBatchProvingInterval,
	}, nil
}

// RequestProof requests proof for the given Taiko batch after Pacaya fork.
func (s *ProofSubmitterPacaya) RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error {
	var (
		headers = make([]*types.Header, len(meta.Pacaya().GetBlocks()))
		g       = new(errgroup.Group)
	)
	// Fetch all blocks headers for the given batch.
	for i := 0; i < len(meta.Pacaya().GetBlocks()); i++ {
		g.Go(func() error {
			header, err := s.rpc.WaitL2Header(
				ctx,
				new(big.Int).SetUint64(
					meta.Pacaya().GetLastBlockID()-
						uint64(len(meta.Pacaya().GetBlocks()))+
						uint64(i)+
						1,
				),
			)
			if err != nil {
				return fmt.Errorf(
					"failed to fetch l2 Header, blockID: %d, error: %w",
					meta.Pacaya().GetLastBlockID(),
					err,
				)
			}

			if header.TxHash == types.EmptyTxsHash {
				return errors.New("no transaction in block")
			}

			headers[i] = header
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		return fmt.Errorf("failed to fetch headers: %w", err)
	}

	// Request proof.
	var (
		opts = &proofProducer.ProofRequestOptionsPacaya{
			BatchID:            meta.Pacaya().GetBatchID(),
			ProverAddress:      s.proverAddress,
			ProposeBlockTxHash: meta.GetTxHash(),
			EventL1Hash:        meta.GetRawBlockHash(),
			Headers:            headers,
		}
		startAt       = time.Now()
		proofResponse *proofProducer.ProofResponse
	)

	// If the prover set address is provided, we use that address as the prover on chain.
	if s.proverSetAddress != rpc.ZeroAddress {
		opts.ProverAddress = s.proverSetAddress
	}

	// Send the generated proof.
	if err := backoff.Retry(
		func() error {
			if ctx.Err() != nil {
				log.Error("Failed to request proof, context is canceled", "batchID", opts.BatchID, "error", ctx.Err())
				return nil
			}
			// Check if there is a need to generate proof, if the proof is already submitted and valid, skip
			// the proof submission.
			proofStatus, err := rpc.GetBatchProofStatus(ctx, s.rpc, meta.Pacaya().GetBatchID())
			if err != nil {
				return err
			}
			if proofStatus.IsSubmitted && !proofStatus.Invalid {
				return nil
			}
			// If zk proof is enabled, request zk proof first, and check if ZK proof is drawn.
			if s.zkvmProofProducer != nil {
				if proofResponse, err = s.requestZKProof(ctx, opts, meta, startAt); err != nil {
					if errors.Is(err, proofProducer.ErrZkAnyNotDrawn) {
						// If zk proof is not drawn, request SGX proof.
						log.Debug("ZK proof was not chosen, attempting to request SGX proof", "batchID", opts.BatchID)
					} else if errors.Is(err, proofProducer.ErrProofGeneartionTimeout) {
						return nil // Skip the proof generation if it has timed out.
					} else {
						return err
					}
				}
			}
			// If zk proof is not enabled or zk proof is not drawn, request the base level proof.
			if proofResponse == nil {
				if proofResponse, err = s.requestBaseLevelProof(ctx, opts, meta, startAt); err != nil {
					if errors.Is(err, proofProducer.ErrProofGeneartionTimeout) {
						return nil // Skip the proof generation if it has timed out.
					}
					return err
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
					meta.Pacaya().GetBatchID(),
					bufferSize,
					err,
				)
			}
			log.Info(
				"Proof generated",
				"batchID", meta.Pacaya().GetBatchID(),
				"bufferSize", bufferSize,
				"maxBufferSize", proofBuffer.MaxLength,
				"proofType", proofResponse.ProofType,
				"bufferIsAggregating", proofBuffer.IsAggregating(),
				"bufferFirstItemAt", proofBuffer.FirstItemAt(),
			)
			// Try to aggregate the proofs in the buffer.
			s.TryAggregate(proofBuffer, proofResponse.ProofType)

			metrics.ProverQueuedProofCounter.Add(1)
			return nil
		},
		backoff.WithContext(backoff.NewConstantBackOff(proofPollingInterval), ctx),
	); err != nil {
		if !errors.Is(err, proofProducer.ErrZkAnyNotDrawn) &&
			!errors.Is(err, proofProducer.ErrProofInProgress) &&
			!errors.Is(err, proofProducer.ErrRetry) {
			log.Error("Failed to request a Pacaya proof", "batchID", meta.Pacaya().GetBatchID(), "error", err)
		} else {
			log.Debug("Expected Pacaya proof generation error", "error", err, "batchID", meta.Pacaya().GetBatchID())
		}
		return err
	}

	return nil
}

// TryAggregate tries to aggregate the proofs in the buffer, if the buffer is full,
// or the forced aggregation interval has passed.
func (s *ProofSubmitterPacaya) TryAggregate(buffer *proofProducer.ProofBuffer, proofType proofProducer.ProofType) bool {
	if !buffer.IsAggregating() &&
		(uint64(buffer.Len()) >= buffer.MaxLength ||
			(buffer.Len() != 0 && time.Since(buffer.FirstItemAt()) > s.forceBatchProvingInterval)) {
		s.batchAggregationNotify <- proofType
		buffer.MarkAggregating()

		return true
	}

	return false
}

// SubmitProof implements the Submitter interface.
func (s *ProofSubmitterPacaya) SubmitProof(
	ctx context.Context,
	proofResponse *proofProducer.ProofResponse,
) (err error) {
	return fmt.Errorf("single proof submission is not supported for Pacaya")
}

// BatchSubmitProofs implements the Submitter interface to submit proof aggregation.
func (s *ProofSubmitterPacaya) BatchSubmitProofs(ctx context.Context, batchProof *proofProducer.BatchProofs) error {
	log.Info(
		"Batch submit batches proofs",
		"proof", common.Bytes2Hex(batchProof.BatchProof),
		"size", len(batchProof.ProofResponses),
		"firstID", batchProof.BlockIDs[0],
		"lastID", batchProof.BlockIDs[len(batchProof.BlockIDs)-1],
		"proofType", batchProof.ProofType,
	)
	var (
		invalidBatchIDs     []uint64
		latestProvenBlockID = common.Big0
		uint64BatchIDs      []uint64
		latestVerifiedID    uint64
	)
	if len(batchProof.ProofResponses) == 0 {
		return proofProducer.ErrInvalidLength
	}

	// Fetch the latest verified block ID.
	batchInfo, err := s.rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		blockInfo, err := s.rpc.GetLastVerifiedBlockOntake(ctx)
		if err != nil {
			log.Warn(
				"Failed to fetch state variables",
				"error", err,
			)
			return err
		}
		latestVerifiedID = blockInfo.BlockId
	} else {
		latestVerifiedID = batchInfo.BatchId
	}
	// Check if any batch in this aggregation is already submitted and valid,
	// if so, we skip this batch.
	for _, proof := range batchProof.ProofResponses {
		uint64BatchIDs = append(uint64BatchIDs, proof.BlockID.Uint64())
		// Check if this proof is still needed to be submitted.
		ok, err := s.sender.ValidateProof(ctx, proof, new(big.Int).SetUint64(latestVerifiedID))
		if err != nil {
			return err
		}
		if !ok {
			log.Error("A valid proof for this batch has already been submitted", "batchID", proof.BlockID)
			invalidBatchIDs = append(invalidBatchIDs, proof.BlockID.Uint64())
			continue
		}

		// Validate each block in each batch.
		for _, blockHeader := range proof.Opts.PacayaOptions().Headers {
			// Get the corresponding L2 block.
			block, err := s.rpc.L2.BlockByHash(ctx, blockHeader.Hash())
			if err != nil {
				log.Error(
					"Failed to get L2 block with given hash",
					"batchID", proof.BlockID,
					"blockID", blockHeader.Number,
					"hash", blockHeader.Hash(),
					"error", err,
				)
				invalidBatchIDs = append(invalidBatchIDs, proof.BlockID.Uint64())
				break
			}

			if block.Transactions().Len() == 0 {
				log.Error(
					"Invalid block without anchor transaction",
					"batchID", proof.BlockID,
					"blockID", block.Number(),
				)
				invalidBatchIDs = append(invalidBatchIDs, proof.BlockID.Uint64())
				break
			}

			// Validate TaikoAnchor.anchoV3 transaction inside the L2 block.
			anchorTx := block.Transactions()[0]
			if err = s.anchorValidator.ValidateAnchorTx(anchorTx); err != nil {
				log.Error("Invalid anchor transaction", "error", err)
				invalidBatchIDs = append(invalidBatchIDs, proof.BlockID.Uint64())
				break
			}
			if new(big.Int).SetUint64(proof.Meta.Pacaya().GetLastBlockID()).Cmp(latestProvenBlockID) > 0 {
				latestProvenBlockID = proof.BlockID
			}
		}
	}

	proofBuffer, exist := s.proofBuffers[batchProof.ProofType]
	if !exist {
		return fmt.Errorf("unexpected proof type from raiko to submit: %s", batchProof.ProofType)
	}
	// If there are invalid batches in the aggregation, we ignore these batches.
	if len(invalidBatchIDs) > 0 {
		log.Warn("Invalid batches in an aggregation, ignore these batches", "batchIDs", invalidBatchIDs)
		proofBuffer.ClearItems(invalidBatchIDs...)
		return ErrInvalidProof
	}

	// Build the TaikoInbox.proveBatches transaction and send it to the L1 node.
	if err := s.sender.SendBatchProof(
		ctx,
		s.txBuilder.BuildProveBatchesPacaya(batchProof),
		batchProof,
	); err != nil {
		if err.Error() == transaction.ErrUnretryableSubmission.Error() {
			return nil
		}
		metrics.ProverAggregationSubmissionErrorCounter.Add(1)
		return err
	}

	metrics.ProverSentProofCounter.Add(float64(len(batchProof.BlockIDs)))
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(latestProvenBlockID.Uint64()))

	// Clear the items in the buffer.
	proofBuffer.ClearItems(uint64BatchIDs...)

	return nil
}

// AggregateProofsByType read all data from buffer and aggregate them.
func (s *ProofSubmitterPacaya) AggregateProofsByType(ctx context.Context, proofType proofProducer.ProofType) error {
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
	if err := backoff.Retry(
		func() error {
			buffer, err := proofBuffer.ReadAll()
			if err != nil {
				return fmt.Errorf("failed to read proof from buffer: %w", err)
			}
			// If the buffer is empty, skip the aggregation.
			if len(buffer) == 0 {
				log.Debug("Buffer is empty now, skip aggregating")
				return nil
			}

			result, err := producer.Aggregate(ctx, buffer, startAt)
			if err != nil {
				if errors.Is(err, proofProducer.ErrProofInProgress) || errors.Is(err, proofProducer.ErrRetry) {
					log.Debug(
						"Aggregating proofs",
						"status", err,
						"batchSize", len(buffer),
						"firstID", buffer[0].BlockID,
						"lastID", buffer[len(buffer)-1].BlockID,
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
		backoff.WithContext(backoff.NewConstantBackOff(proofPollingInterval), ctx),
	); err != nil {
		log.Error("Aggregate proof error", "error", err)
		return err
	}
	return nil
}

// AggregateProofs implements the Submitter interface.
func (s *ProofSubmitterPacaya) AggregateProofs(ctx context.Context) error {
	return fmt.Errorf("AggregateProofs is not implemented for Pacaya submitter")
}

// Producer implements the Submitter interface.
func (s *ProofSubmitterPacaya) Producer() proofProducer.ProofProducer {
	log.Warn("Producer is not implemented for Pacaya submitter")
	return nil
}

// Tier implements the Submitter interface.
func (s *ProofSubmitterPacaya) Tier() uint16 {
	log.Warn("Tier is not implemented for Pacaya submitter")
	return 0
}

// BufferSize implements the Submitter interface.
func (s *ProofSubmitterPacaya) BufferSize() uint64 {
	log.Warn("BufferSize is not implemented for Pacaya submitter")
	return 0
}

// AggregationEnabled implements the Submitter interface.
func (s *ProofSubmitterPacaya) AggregationEnabled() bool {
	// Aggregation is always enabled for Pacaya.
	return true
}

// requestZKProof requests the ZK proof from the producer, if zk proof is not enabled,
// it will return a nil response.
func (s *ProofSubmitterPacaya) requestZKProof(
	ctx context.Context,
	opts proofProducer.ProofRequestOptions,
	meta metadata.TaikoProposalMetaData,
	startAt time.Time,
) (*proofProducer.ProofResponse, error) {
	response, err := s.zkvmProofProducer.RequestProof(ctx, opts, meta.Pacaya().GetBatchID(), meta, startAt)
	if err != nil {
		if errors.Is(err, proofProducer.ErrProofInProgress) && time.Since(startAt) >= ProofTimeout {
			log.Error(
				"Request proof has timed out, start to cancel",
				"batchID", meta.Pacaya().GetBatchID(),
			)
			if cancelErr := s.zkvmProofProducer.RequestCancel(ctx, opts); cancelErr != nil {
				log.Error("Failed to request cancellation of proof", "err", cancelErr)
			}
			return nil, proofProducer.ErrProofGeneartionTimeout
		} else {
			log.Error(
				"Request new proof error",
				"batchID", meta.Pacaya().GetBatchID(),
				"proofType", "zkAny",
				"error", err,
			)
			return nil, err
		}
	}

	return response, nil
}

// requestBaseLevelProof requests the base level proof from the producer.
func (s *ProofSubmitterPacaya) requestBaseLevelProof(
	ctx context.Context,
	opts proofProducer.ProofRequestOptions,
	meta metadata.TaikoProposalMetaData,
	startAt time.Time,
) (*proofProducer.ProofResponse, error) {
	response, err := s.baseLevelProofProducer.RequestProof(ctx, opts, meta.Pacaya().GetBatchID(), meta, startAt)
	if err != nil {
		// If request proof has timed out, let's cancel the proof generating and skip this proof.
		if errors.Is(err, proofProducer.ErrProofInProgress) && time.Since(startAt) >= ProofTimeout {
			log.Error("Request proof has timed out, start to cancel", "batchID", opts.PacayaOptions().BatchID)
			if cancelErr := s.baseLevelProofProducer.RequestCancel(ctx, opts); cancelErr != nil {
				log.Error("Failed to request cancellation of proof", "err", cancelErr)
			}
			return nil, proofProducer.ErrProofGeneartionTimeout
		}
		return nil, fmt.Errorf("failed to request proof (id: %d): %w", meta.Pacaya().GetBatchID(), err)
	}

	return response, nil
}
