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
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	validator "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/anchor_tx_validator"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

var (
	_                              Submitter = (*ProofSubmitter)(nil)
	submissionDelayRandomBumpRange float64   = 20
	proofPollingInterval                     = 10 * time.Second
	ProofTimeout                             = 3 * time.Hour
	ErrInvalidProof                          = errors.New("invalid proof found")
)

// ProofSubmitter is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoL1 smart contract.
type ProofSubmitter struct {
	rpc               *rpc.Client
	proofProducer     proofProducer.ProofProducer
	resultCh          chan *proofProducer.ProofWithHeader
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
	proofBuffer *ProofBuffer
}

// NewProofSubmitter creates a new ProofSubmitter instance.
func NewProofSubmitter(
	rpcClient *rpc.Client,
	proofProducer proofProducer.ProofProducer,
	resultCh chan *proofProducer.ProofWithHeader,
	batchResultCh chan *proofProducer.BatchProofs,
	aggregationNotify chan uint16,
	proverSetAddress common.Address,
	taikoL2Address common.Address,
	graffiti string,
	gasLimit uint64,
	txmgr *txmgr.SimpleTxManager,
	privateTxmgr *txmgr.SimpleTxManager,
	builder *transaction.ProveBlockTxBuilder,
	tiers []*rpc.TierProviderTierWithID,
	isGuardian bool,
	submissionDelay time.Duration,
	proofBufferSize uint64,
) (*ProofSubmitter, error) {
	anchorValidator, err := validator.New(taikoL2Address, rpcClient.L2.ChainID, rpcClient)
	if err != nil {
		return nil, err
	}

	return &ProofSubmitter{
		rpc:               rpcClient,
		proofProducer:     proofProducer,
		resultCh:          resultCh,
		batchResultCh:     batchResultCh,
		aggregationNotify: aggregationNotify,
		anchorValidator:   anchorValidator,
		txBuilder:         builder,
		sender:            transaction.NewSender(rpcClient, txmgr, privateTxmgr, proverSetAddress, gasLimit),
		proverAddress:     txmgr.From(),
		proverSetAddress:  proverSetAddress,
		taikoL2Address:    taikoL2Address,
		graffiti:          rpc.StringToBytes32(graffiti),
		tiers:             tiers,
		isGuardian:        isGuardian,
		submissionDelay:   submissionDelay,
		proofBuffer:       NewProofBuffer(proofBufferSize),
	}, nil
}

// RequestProof implements the Submitter interface.
func (s *ProofSubmitter) RequestProof(ctx context.Context, meta metadata.TaikoBlockMetaData) error {
	var (
		blockInfo bindings.TaikoDataBlockV2
	)

	header, err := s.rpc.WaitL2Header(ctx, meta.GetBlockID())
	if err != nil {
		return fmt.Errorf("failed to fetch l2 Header, blockID: %d, error: %w", meta.GetBlockID(), err)
	}

	if header.TxHash == types.EmptyTxsHash {
		return errors.New("no transaction in block")
	}

	parent, err := s.rpc.L2.BlockByHash(ctx, header.ParentHash)
	if err != nil {
		return fmt.Errorf("failed to get the L2 parent block by hash (%s): %w", header.ParentHash, err)
	}

	if meta.IsOntakeBlock() {
		blockInfo, err = s.rpc.GetL2BlockInfoV2(ctx, meta.GetBlockID())
	} else {
		blockInfo, err = s.rpc.GetL2BlockInfo(ctx, meta.GetBlockID())
	}
	if err != nil {
		return err
	}

	// Request proof.
	opts := &proofProducer.ProofRequestOptions{
		BlockID:            header.Number,
		ProverAddress:      s.proverAddress,
		ProposeBlockTxHash: meta.GetTxHash(),
		TaikoL2:            s.taikoL2Address,
		MetaHash:           blockInfo.MetaHash,
		BlockHash:          header.Hash(),
		ParentHash:         header.ParentHash,
		StateRoot:          header.Root,
		EventL1Hash:        meta.GetRawBlockHash(),
		Graffiti:           common.Bytes2Hex(s.graffiti[:]),
		GasUsed:            header.GasUsed,
		ParentGasUsed:      parent.GasUsed(),
		Compressed:         s.proofBuffer.MaxLength > 1,
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
			// Check if the proof buffer is full
			if s.proofBuffer.MaxLength > 1 && s.proofBuffer.MaxLength == uint64(s.proofBuffer.Len()) {
				log.Debug("Buffer is full now", "blockID", meta.GetBlockID())
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
				meta.GetBlockID(),
				meta,
				header,
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
				return fmt.Errorf("failed to request proof (id: %d): %w", meta.GetBlockID(), err)
			}
			if meta.IsOntakeBlock() && s.proofBuffer.MaxLength > 1 {
				bufferSize, err := s.proofBuffer.Write(result)
				if err != nil {
					return fmt.Errorf("failed to add proof into buffer (id: %d)(current buffer size: %d): %w",
						meta.GetBlockID(),
						bufferSize,
						err,
					)
				}
				log.Debug("Succeed to generate proof",
					"blockID", meta.GetBlockID(),
					"bufferSize", bufferSize,
				)
				if s.proofBuffer.MaxLength == uint64(bufferSize) {
					s.aggregationNotify <- s.Tier()
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
func (s *ProofSubmitter) SubmitProof(
	ctx context.Context,
	proofWithHeader *proofProducer.ProofWithHeader,
) (err error) {
	log.Info(
		"Submit block proof",
		"blockID", proofWithHeader.BlockID,
		"coinbase", proofWithHeader.Meta.GetCoinbase(),
		"parentHash", proofWithHeader.Header.ParentHash,
		"hash", proofWithHeader.Opts.BlockHash,
		"stateRoot", proofWithHeader.Opts.StateRoot,
		"proof", common.Bytes2Hex(proofWithHeader.Proof),
		"tier", proofWithHeader.Tier,
	)

	// Check if we still need to generate a new proof for that block.
	proofStatus, err := rpc.GetBlockProofStatus(ctx, s.rpc, proofWithHeader.BlockID, s.proverAddress, s.proverSetAddress)
	if err != nil {
		return err
	}
	if proofStatus.IsSubmitted && !proofStatus.Invalid {
		return nil
	}

	if s.isGuardian {
		_, expiredAt, _, err := handler.IsProvingWindowExpired(proofWithHeader.Meta, s.tiers)
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
			proofWithHeader.BlockID,
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
	block, err := s.rpc.L2.BlockByHash(ctx, proofWithHeader.Header.Hash())
	if err != nil {
		return fmt.Errorf("failed to get L2 block with given hash %s: %w", proofWithHeader.Header.Hash(), err)
	}

	if block.Transactions().Len() == 0 {
		return fmt.Errorf("invalid block without anchor transaction, blockID %s", proofWithHeader.BlockID)
	}

	// Validate TaikoL2.anchor transaction inside the L2 block.
	anchorTx := block.Transactions()[0]
	if err = s.anchorValidator.ValidateAnchorTx(anchorTx); err != nil {
		return fmt.Errorf("invalid anchor transaction: %w", err)
	}

	// Build the TaikoL1.proveBlock transaction and send it to the L1 node.
	if err = s.sender.Send(
		ctx,
		proofWithHeader,
		s.txBuilder.Build(
			proofWithHeader.BlockID,
			proofWithHeader.Meta,
			&bindings.TaikoDataTransition{
				ParentHash: proofWithHeader.Header.ParentHash,
				BlockHash:  proofWithHeader.Opts.BlockHash,
				StateRoot:  proofWithHeader.Opts.StateRoot,
				Graffiti:   s.graffiti,
			},
			&bindings.TaikoDataTierProof{
				Tier: proofWithHeader.Tier,
				Data: proofWithHeader.Proof,
			},
			proofWithHeader.Tier,
		),
	); err != nil {
		if err.Error() == transaction.ErrUnretryableSubmission.Error() {
			return nil
		}
		metrics.ProverSubmissionErrorCounter.Add(1)
		return err
	}

	metrics.ProverSentProofCounter.Add(1)
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(proofWithHeader.BlockID.Uint64()))

	return nil
}

// BatchSubmitProofs implements the Submitter interface to submit proof aggregation.
func (s *ProofSubmitter) BatchSubmitProofs(ctx context.Context, batchProof *proofProducer.BatchProofs) error {
	log.Info(
		"Batch submit block proofs",
		"proof", common.Bytes2Hex(batchProof.BatchProof),
		"blockIds", batchProof.BlockIDs,
		"tier", batchProof.Tier,
	)
	var (
		invalidBlockIds     []uint64
		latestProvenBlockID = big.NewInt(0)
	)
	if len(batchProof.Proofs) == 0 {
		return proofProducer.ErrInvalidLength
	}
	// Check if the proof has already been submitted.
	proofStatus, err := rpc.BatchGetBlocksProofStatus(
		ctx,
		s.rpc,
		batchProof.BlockIDs,
		batchProof.Proofs[0].Opts.ProverAddress,
		s.proverSetAddress,
	)
	if err != nil {
		return err
	}
	stateVars, err := s.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Warn(
			"Failed to fetch state variables",
			"error", err,
		)
		return err
	}
	for i, proof := range batchProof.Proofs {
		// Check if this proof is still needed to be submitted.
		ok, err := s.sender.ValidateProof(ctx, proof, new(big.Int).SetUint64(stateVars.B.LastVerifiedBlockId))
		if err != nil {
			return err
		}
		if !ok {
			log.Error("a valid proof for block is already submitted", "blockId", proof.BlockID)
			invalidBlockIds = append(invalidBlockIds, proof.BlockID.Uint64())
			continue
		}

		if proofStatus[i].IsSubmitted && !proofStatus[i].Invalid {
			log.Error("a valid proof for block is already submitted", "blockId", proof.BlockID)
			invalidBlockIds = append(invalidBlockIds, proof.BlockID.Uint64())
			continue
		}

		// Get the corresponding L2 block.
		block, err := s.rpc.L2.BlockByHash(ctx, proof.Header.Hash())
		if err != nil {
			log.Error("failed to get L2 block with given hash",
				"hash", proof.Header.Hash(),
				"error", err,
			)
			invalidBlockIds = append(invalidBlockIds, proof.BlockID.Uint64())
			continue
		}

		if block.Transactions().Len() == 0 {
			log.Error("Invalid block without anchor transaction, blockID", "blockId", proof.BlockID)
			invalidBlockIds = append(invalidBlockIds, proof.BlockID.Uint64())
			continue
		}

		// Validate TaikoL2.anchor transaction inside the L2 block.
		anchorTx := block.Transactions()[0]
		if err = s.anchorValidator.ValidateAnchorTx(anchorTx); err != nil {
			log.Error("Invalid anchor transaction", "error", err)
			invalidBlockIds = append(invalidBlockIds, proof.BlockID.Uint64())
		}
		if proof.BlockID.Cmp(latestProvenBlockID) > 0 {
			latestProvenBlockID = proof.BlockID
		}
	}

	if len(invalidBlockIds) > 0 {
		log.Warn("Detected invalid proofs", "blockIds", invalidBlockIds)
		s.proofBuffer.ClearItems(invalidBlockIds...)
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
	s.proofBuffer.Clear()

	return nil
}

// AggregateProofs read all data from buffer and aggregate them.
func (s *ProofSubmitter) AggregateProofs(ctx context.Context) error {
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
				log.Error("Failed to request proof aggregation", "err", err)
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
func (s *ProofSubmitter) getRandomBumpedSubmissionDelay(expiredAt time.Time) (time.Duration, error) {
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
func (s *ProofSubmitter) Producer() proofProducer.ProofProducer {
	return s.proofProducer
}

// Tier returns the proof tier of the current proof submitter.
func (s *ProofSubmitter) Tier() uint16 {
	return s.proofProducer.Tier()
}

// BufferSize returns the size of the proof buffer.
func (s *ProofSubmitter) BufferSize() uint64 {
	return s.proofBuffer.MaxLength
}
