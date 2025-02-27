package submitter

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	validator "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/anchor_tx_validator"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

// ProofSubmitterOntake is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoL1 smart contract.
type ProofSubmitterOntake struct {
	rpc               *rpc.Client
	proofProducer     proofProducer.ProofProducer
	resultCh          chan *proofProducer.ProofResponse
	batchResultCh     chan *proofProducer.BatchProofs
	aggregationNotify chan uint16
	anchorValidator   *validator.AnchorTxValidator
	txBuilder         *transaction.ProveBlockTxBuilder
	sender            *transaction.Sender
	proverAddress     common.Address
	proverSetAddress  common.Address
	taikoL2Address    common.Address
	graffiti          [32]byte
	tiers             []*rpc.TierProviderTierWithID
	// Guardian prover related.
	isGuardian      bool
	submissionDelay time.Duration
	// Batch proof related
	proofBuffer               *ProofBuffer
	forceBatchProvingInterval time.Duration
}

// NewProofSubmitterOntake creates a new ProofSubmitter instance.
func NewProofSubmitterOntake(
	rpcClient *rpc.Client,
	proofProducer proofProducer.ProofProducer,
	resultCh chan *proofProducer.ProofResponse,
	batchResultCh chan *proofProducer.BatchProofs,
	aggregationNotify chan uint16,
	proverSetAddress common.Address,
	taikoL2Address common.Address,
	graffiti string,
	gasLimit uint64,
	txmgr txmgr.TxManager,
	privateTxmgr txmgr.TxManager,
	builder *transaction.ProveBlockTxBuilder,
	tiers []*rpc.TierProviderTierWithID,
	isGuardian bool,
	submissionDelay time.Duration,
	proofBufferSize uint64,
	forceBatchProvingInterval time.Duration,
) (*ProofSubmitterOntake, error) {
	anchorValidator, err := validator.New(taikoL2Address, rpcClient.L2.ChainID, rpcClient)
	if err != nil {
		return nil, err
	}

	return &ProofSubmitterOntake{
		rpc:                       rpcClient,
		proofProducer:             proofProducer,
		resultCh:                  resultCh,
		batchResultCh:             batchResultCh,
		aggregationNotify:         aggregationNotify,
		anchorValidator:           anchorValidator,
		txBuilder:                 builder,
		sender:                    transaction.NewSender(rpcClient, txmgr, privateTxmgr, proverSetAddress, gasLimit),
		proverAddress:             txmgr.From(),
		proverSetAddress:          proverSetAddress,
		taikoL2Address:            taikoL2Address,
		graffiti:                  rpc.StringToBytes32(graffiti),
		tiers:                     tiers,
		isGuardian:                isGuardian,
		submissionDelay:           submissionDelay,
		proofBuffer:               NewProofBuffer(proofBufferSize),
		forceBatchProvingInterval: forceBatchProvingInterval,
	}, nil
}

// RequestProof implements the Submitter interface.
func (s *ProofSubmitterOntake) RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error {
	var (
		header *types.Header
		parent *types.Header
		err    error
	)

	if header, err = s.rpc.WaitL2Header(ctx, meta.Ontake().GetBlockID()); err != nil {
		return fmt.Errorf(
			"failed to fetch l2 Header, blockID: %d, error: %w",
			meta.Ontake().GetBlockID(),
			err,
		)
	}

	if header.TxHash == types.EmptyTxsHash {
		return errors.New("no transaction in block")
	}

	if parent, err = s.rpc.L2.HeaderByHash(ctx, header.ParentHash); err != nil {
		return fmt.Errorf("failed to get the L2 parent block by hash (%s): %w", header.ParentHash, err)
	}

	// Request proof.
	opts := &proofProducer.ProofRequestOptionsOntake{
		BlockID:            header.Number,
		ProverAddress:      s.proverAddress,
		ProposeBlockTxHash: meta.GetTxHash(),
		BlockHash:          header.Hash(),
		ParentHash:         header.ParentHash,
		StateRoot:          header.Root,
		EventL1Hash:        meta.GetRawBlockHash(),
		Graffiti:           common.Bytes2Hex(s.graffiti[:]),
		GasUsed:            header.GasUsed,
		ParentGasUsed:      parent.GasUsed,
		Compressed:         s.proofBuffer.Enabled(),
	}

	// If the prover set address is provided, we use that address as the prover on chain.
	if s.proverSetAddress != rpc.ZeroAddress {
		opts.ProverAddress = s.proverSetAddress
	}
	startTime := time.Now()

	// Send the generated proof.
	if err := backoff.Retry(
		func() error {
			if ctx.Err() != nil {
				log.Error("Failed to request proof, context is canceled", "blockID", opts.BlockID, "error", ctx.Err())
				return nil
			}
			// Check if the proof buffer is full.
			if s.proofBuffer.Enabled() && uint64(s.proofBuffer.Len()) >= s.proofBuffer.MaxLength {
				log.Warn(
					"Proof buffer is full now",
					"blockID", meta.Ontake().GetBlockID(),
					"tier", meta.Ontake().GetMinTier(),
					"size", s.proofBuffer.Len(),
				)
				return errBufferOverflow
			}
			// Check if there is a need to generate proof
			proofStatus, err := rpc.GetBlockProofStatus(
				ctx,
				s.rpc,
				opts.BlockID,
				opts.ProverAddress,
				s.proverSetAddress,
			)
			if err != nil {
				return err
			}
			if proofStatus.IsSubmitted && !proofStatus.Invalid {
				return nil
			}

			result, err := s.proofProducer.RequestProof(
				ctx,
				opts,
				meta.Ontake().GetBlockID(),
				meta,
				startTime,
			)
			if err != nil {
				// If request proof has timed out in retry, let's cancel the proof generating and skip
				if errors.Is(err, proofProducer.ErrProofInProgress) && time.Since(startTime) >= ProofTimeout {
					log.Error("Request proof has timed out, start to cancel", "blockID", opts.BlockID)
					if cancelErr := s.proofProducer.RequestCancel(ctx, opts); cancelErr != nil {
						log.Error("Failed to request cancellation of proof", "err", cancelErr)
					}
					return nil
				}
				if errors.Is(err, proofProducer.ErrZkAnyNotDrawn) {
					return backoff.Permanent(err)
				}
				return fmt.Errorf("failed to request proof (id: %d): %w", meta.Ontake().GetBlockID(), err)
			}
			if s.proofBuffer.Enabled() {
				bufferSize, err := s.proofBuffer.Write(result)
				if err != nil {
					return fmt.Errorf(
						"failed to add proof into buffer (id: %d) (current buffer size: %d): %w",
						meta.Ontake().GetBlockID(),
						bufferSize,
						err,
					)
				}
				log.Info(
					"Proof generated",
					"blockID", meta.Ontake().GetBlockID(),
					"bufferSize", bufferSize,
					"maxBufferSize", s.proofBuffer.MaxLength,
					"proofType", result.ProofType,
					"bufferIsAggregating", s.proofBuffer.IsAggregating(),
					"bufferLastUpdatedAt", s.proofBuffer.lastUpdatedAt,
				)
				// Check if we need to aggregate proofs.
				if !s.proofBuffer.IsAggregating() &&
					(uint64(bufferSize) >= s.proofBuffer.MaxLength ||
						time.Since(s.proofBuffer.lastUpdatedAt) > s.forceBatchProvingInterval) {
					s.aggregationNotify <- s.Tier()
					s.proofBuffer.MarkAggregating()
				}
			} else {
				s.resultCh <- result
			}
			metrics.ProverQueuedProofCounter.Add(1)
			return nil
		},
		backoff.WithContext(backoff.NewConstantBackOff(proofPollingInterval), ctx),
	); err != nil {
		log.Error("Request proof error", "error", err)
		return err
	}

	return nil
}

// SubmitProof implements the Submitter interface.
func (s *ProofSubmitterOntake) SubmitProof(
	ctx context.Context,
	proofResponse *proofProducer.ProofResponse,
) (err error) {
	log.Info(
		"Submit block proof",
		"blockID", proofResponse.BlockID,
		"coinbase", proofResponse.Meta.Ontake().GetCoinbase(),
		"parentHash", proofResponse.Opts.OntakeOptions().ParentHash,
		"proof", common.Bytes2Hex(proofResponse.Proof),
		"tier", proofResponse.Tier,
		"proofType", proofResponse.ProofType,
	)

	// Check if we still need to generate a new proof for that block.
	var proofStatus *rpc.BlockProofStatus

	if proofStatus, err = rpc.GetBlockProofStatus(
		ctx,
		s.rpc,
		proofResponse.Meta.Ontake().GetBlockID(),
		s.proverAddress,
		s.proverSetAddress,
	); err != nil {
		return err
	}

	if proofStatus.IsSubmitted && !proofStatus.Invalid {
		return nil
	}

	if s.isGuardian {
		_, expiredAt, _, err := handler.IsProvingWindowExpired(s.rpc, proofResponse.Meta, s.tiers)
		if err != nil {
			return fmt.Errorf("failed to check if the proving window is expired: %w", err)
		}
		// Get a random bumped submission delay, if necessary.
		submissionDelay, err := s.getRandomBumpedSubmissionDelay(expiredAt)
		if err != nil {
			return err
		}
		// Wait for the submission delay.
		<-time.After(submissionDelay)

		// Check the proof submission status again.
		proofStatus, err := rpc.GetBlockProofStatus(
			ctx,
			s.rpc,
			proofResponse.BlockID,
			s.proverAddress,
			s.proverSetAddress,
		)
		if err != nil {
			return err
		}
		if proofStatus.IsSubmitted && !proofStatus.Invalid {
			return nil
		}
	}

	metrics.ProverReceivedProofCounter.Add(1)

	// Get the corresponding L2 block.
	block, err := s.rpc.L2.BlockByHash(ctx, proofResponse.Opts.OntakeOptions().BlockHash)
	if err != nil {
		return fmt.Errorf(
			"failed to get L2 block with given hash %s: %w",
			proofResponse.Opts.OntakeOptions().BlockHash,
			err,
		)
	}

	if block.Transactions().Len() == 0 {
		return fmt.Errorf("invalid block without anchor transaction, blockID %s", proofResponse.BlockID)
	}

	// Validate TaikoL2.anchorV2 / TaikoAnchor.anchorV3 transaction inside the L2 block.
	anchorTx := block.Transactions()[0]
	if err = s.anchorValidator.ValidateAnchorTx(anchorTx); err != nil {
		return fmt.Errorf("invalid anchor transaction: %w", err)
	}

	// Build the TaikoL1.proveBlock transaction and send it to the L1 node.
	var tier uint16
	switch proofResponse.ProofType {
	case proofProducer.ZKProofTypeR0:
		tier = encoding.TierZkVMRisc0ID
	case proofProducer.ZKProofTypeSP1:
		tier = encoding.TierZkVMSp1ID
	default:
		tier = proofResponse.Tier
	}
	if err = s.sender.Send(
		ctx,
		proofResponse,
		s.txBuilder.Build(
			proofResponse.BlockID,
			proofResponse.Meta,
			&ontakeBindings.TaikoDataTransition{
				ParentHash: proofResponse.Opts.OntakeOptions().ParentHash,
				BlockHash:  proofResponse.Opts.OntakeOptions().BlockHash,
				StateRoot:  proofResponse.Opts.OntakeOptions().StateRoot,
				Graffiti:   s.graffiti,
			},
			&ontakeBindings.TaikoDataTierProof{
				Tier: tier,
				Data: proofResponse.Proof,
			},
			proofResponse.Tier,
		),
	); err != nil {
		if err.Error() == transaction.ErrUnretryableSubmission.Error() {
			return nil
		}
		metrics.ProverSubmissionErrorCounter.Add(1)
		return err
	}

	metrics.ProverSentProofCounter.Add(1)
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(proofResponse.BlockID.Uint64()))

	return nil
}

// BatchSubmitProofs implements the Submitter interface to submit proof aggregation.
func (s *ProofSubmitterOntake) BatchSubmitProofs(ctx context.Context, batchProof *proofProducer.BatchProofs) error {
	log.Info(
		"Batch submit block proofs",
		"proof", common.Bytes2Hex(batchProof.BatchProof),
		"size", len(batchProof.ProofResponses),
		"firstID", batchProof.BlockIDs[0],
		"lastID", batchProof.BlockIDs[len(batchProof.BlockIDs)-1],
		"tier", batchProof.Tier,
	)
	var (
		invalidBlockIDs     []uint64
		latestProvenBlockID = common.Big0
		uint64BlockIDs      []uint64
	)
	if len(batchProof.ProofResponses) == 0 {
		return proofProducer.ErrInvalidLength
	}
	// Check if the proof has already been submitted.
	proofStatus, err := rpc.BatchGetBlocksProofStatus(
		ctx,
		s.rpc,
		batchProof.BlockIDs,
		batchProof.ProofResponses[0].Opts.GetProverAddress(),
		s.proverSetAddress,
	)
	if err != nil {
		return err
	}
	blockInfo, err := s.rpc.GetLastVerifiedBlockOntake(ctx)
	if err != nil {
		log.Warn(
			"Failed to fetch state variables",
			"error", err,
		)
		return err
	}
	for i, proof := range batchProof.ProofResponses {
		uint64BlockIDs = append(uint64BlockIDs, proof.BlockID.Uint64())
		// Check if this proof is still needed to be submitted.
		ok, err := s.sender.ValidateProof(ctx, proof, new(big.Int).SetUint64(blockInfo.BlockId))
		if err != nil {
			return err
		}
		if !ok {
			log.Error("A valid proof for block is already submitted", "blockId", proof.BlockID)
			invalidBlockIDs = append(invalidBlockIDs, proof.BlockID.Uint64())
			continue
		}

		if proofStatus[i].IsSubmitted && !proofStatus[i].Invalid {
			log.Error("A valid proof for block is already submitted", "blockId", proof.BlockID)
			invalidBlockIDs = append(invalidBlockIDs, proof.BlockID.Uint64())
			continue
		}

		// Get the corresponding L2 block.
		block, err := s.rpc.L2.BlockByHash(ctx, proof.Opts.OntakeOptions().BlockHash)
		if err != nil {
			log.Error(
				"Failed to get L2 block with given hash",
				"hash", proof.Opts.OntakeOptions().BlockHash,
				"error", err,
			)
			invalidBlockIDs = append(invalidBlockIDs, proof.BlockID.Uint64())
			continue
		}

		if block.Transactions().Len() == 0 {
			log.Error("Invalid block without anchor transaction, blockID", "blockId", proof.BlockID)
			invalidBlockIDs = append(invalidBlockIDs, proof.BlockID.Uint64())
			continue
		}

		// Validate TaikoL2.anchor transaction inside the L2 block.
		anchorTx := block.Transactions()[0]
		if err = s.anchorValidator.ValidateAnchorTx(anchorTx); err != nil {
			log.Error("Invalid anchor transaction", "error", err)
			invalidBlockIDs = append(invalidBlockIDs, proof.BlockID.Uint64())
		}
		if proof.BlockID.Cmp(latestProvenBlockID) > 0 {
			latestProvenBlockID = proof.BlockID
		}
	}

	if len(invalidBlockIDs) > 0 {
		log.Warn("Invalid proofs in batch", "blockIds", invalidBlockIDs)
		s.proofBuffer.ClearItems(invalidBlockIDs...)
		return ErrInvalidProof
	}

	// Build the TaikoL1.proveBlocks transaction and send it to the L1 node.
	if err := s.sender.SendBatchProof(
		ctx,
		s.txBuilder.BuildProveBlocks(batchProof, s.graffiti),
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
	s.proofBuffer.ClearItems(uint64BlockIDs...)
	// Each time we submit a batch proof, we should update the LastUpdatedAt() of the buffer.
	s.proofBuffer.UpdateLastUpdatedAt()

	return nil
}

// AggregateProofs read all data from buffer and aggregate them.
func (s *ProofSubmitterOntake) AggregateProofs(ctx context.Context) error {
	startTime := time.Now()
	if err := backoff.Retry(
		func() error {
			buffer, err := s.proofBuffer.ReadAll()
			if err != nil {
				return fmt.Errorf("failed to read proof from buffer: %w", err)
			}
			if len(buffer) == 0 {
				log.Debug("Buffer is empty now, skip aggregating")
				return nil
			}

			result, err := s.proofProducer.Aggregate(
				ctx,
				buffer,
				startTime,
			)
			if err != nil {
				if errors.Is(err, proofProducer.ErrProofInProgress) ||
					errors.Is(err, proofProducer.ErrRetry) {
					log.Info(
						"Aggregating proofs",
						"status", err,
						"batchSize", len(buffer),
						"firstID", buffer[0].BlockID,
						"lastID", buffer[len(buffer)-1].BlockID,
						"tier", s.Tier(),
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

// getRandomBumpedSubmissionDelay returns a random bumped submission delay.
func (s *ProofSubmitterOntake) getRandomBumpedSubmissionDelay(expiredAt time.Time) (time.Duration, error) {
	if s.submissionDelay == 0 {
		return s.submissionDelay, nil
	}

	randomBump, err := rand.Int(
		rand.Reader,
		new(big.Int).SetUint64(uint64(s.submissionDelay.Seconds()*submissionDelayRandomBumpRange/100)),
	)
	if err != nil {
		return 0, err
	}

	delay := time.Duration(s.submissionDelay.Seconds()+float64(randomBump.Uint64())) * time.Second

	if time.Since(expiredAt) >= delay {
		return 0, nil
	}

	return delay - time.Since(expiredAt), nil
}

// Producer returns the inner proof producer.
func (s *ProofSubmitterOntake) Producer() proofProducer.ProofProducer {
	return s.proofProducer
}

// Tier returns the proof tier of the current proof submitter.
func (s *ProofSubmitterOntake) Tier() uint16 {
	return s.proofProducer.Tier()
}

// BufferSize returns the size of the proof buffer.
func (s *ProofSubmitterOntake) BufferSize() uint64 {
	return s.proofBuffer.MaxLength
}

// AggregationEnabled returns whether the proof submitter's aggregation feature is enabled.
func (s *ProofSubmitterOntake) AggregationEnabled() bool {
	return s.proofBuffer.Enabled()
}
