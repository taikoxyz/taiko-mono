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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	validator "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/anchor_tx_validator"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

// ProofSubmitterPacaya is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoL1 smart contract.
type ProofSubmitterPacaya struct {
	rpc                *rpc.Client
	proofProducer      proofProducer.ProofProducer
	resultCh           chan *proofProducer.ProofWithHeader
	batchResultCh      chan *proofProducer.BatchProofs
	aggregationNotify  chan uint16
	anchorValidator    *validator.AnchorTxValidator
	txBuilder          *transaction.ProveBlockTxBuilder
	sender             *transaction.Sender
	proverAddress      common.Address
	proverSetAddress   common.Address
	taikoAnchorAddress common.Address
}

// NewProofSubmitter creates a new ProofSubmitter instance.
func NewProofSubmitterPacaya(
	rpcClient *rpc.Client,
	proofProducer proofProducer.ProofProducer,
	resultCh chan *proofProducer.ProofWithHeader,
	batchResultCh chan *proofProducer.BatchProofs,
	aggregationNotify chan uint16,
	proverSetAddress common.Address,
	taikoAnchorAddress common.Address,
	graffiti string,
	gasLimit uint64,
	txmgr *txmgr.SimpleTxManager,
	privateTxmgr *txmgr.SimpleTxManager,
	builder *transaction.ProveBlockTxBuilder,
) (*ProofSubmitterPacaya, error) {
	anchorValidator, err := validator.New(taikoAnchorAddress, rpcClient.L2.ChainID, rpcClient)
	if err != nil {
		return nil, err
	}

	return &ProofSubmitterPacaya{
		rpc:                rpcClient,
		proofProducer:      proofProducer,
		resultCh:           resultCh,
		batchResultCh:      batchResultCh,
		aggregationNotify:  aggregationNotify,
		anchorValidator:    anchorValidator,
		txBuilder:          builder,
		sender:             transaction.NewSender(rpcClient, txmgr, privateTxmgr, proverSetAddress, gasLimit),
		proverAddress:      txmgr.From(),
		proverSetAddress:   proverSetAddress,
		taikoAnchorAddress: taikoAnchorAddress,
	}, nil
}

// RequestProof requests proof for the given Taiko batch after Pacaya fork.
func (s *ProofSubmitterPacaya) RequestProof(ctx context.Context, meta metadata.TaikoProposalMetaData) error {
	var (
		headers []*types.Header
		err     error
	)

	batch, err := s.rpc.GetBatchByID(ctx, meta.TaikoBatchMetaDataPacaya().GetBatchID())
	if err != nil {
		return err
	}
	for i := 0; i < len(meta.TaikoBatchMetaDataPacaya().GetBlocks()); i++ {
		header, err := s.rpc.WaitL2Header(
			ctx,
			new(big.Int).SetUint64(batch.LastBlockId-uint64(len(meta.TaikoBatchMetaDataPacaya().GetBlocks()))+uint64(i)+1),
		)
		if err != nil {
			return fmt.Errorf(
				"failed to fetch l2 Header, blockID: %d, error: %w",
				batch.LastBlockId,
				err,
			)
		}

		if header.TxHash == types.EmptyTxsHash {
			return errors.New("no transaction in block")
		}

		headers = append(headers, header)
	}

	// Request proof.
	opts := &proofProducer.ProofRequestOptionsPacaya{
		BatchID:            meta.TaikoBatchMetaDataPacaya().GetBatchID(),
		ProverAddress:      s.proverAddress,
		ProposeBlockTxHash: meta.GetTxHash(),
		MetaHash:           batch.MetaHash,
		EventL1Hash:        meta.GetRawBlockHash(),
		Headers:            headers,
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
				log.Error("Failed to request proof, context is canceled", "batchID", opts.BatchID, "error", ctx.Err())
				return nil
			}
			// Check if there is a need to generate proof
			proofStatus, err := rpc.GetBatchProofStatus(
				ctx,
				s.rpc,
				new(big.Int).SetUint64(batch.BatchId),
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
				new(big.Int).SetUint64(batch.BatchId),
				meta,
				startTime,
			)
			if err != nil {
				// If request proof has timed out in retry, let's cancel the proof generating and skip
				if errors.Is(err, proofProducer.ErrProofInProgress) && time.Since(startTime) >= ProofTimeout {
					log.Error("Request proof has timed out, start to cancel", "batchID", batch.BatchId)
					if cancelErr := s.proofProducer.RequestCancel(ctx, opts); cancelErr != nil {
						log.Error("Failed to request cancellation of proof", "err", cancelErr)
					}
					return nil
				}
				return fmt.Errorf("failed to request proof (id: %d): %w", batch.BatchId, err)
			}

			s.resultCh <- result
			metrics.ProverQueuedProofCounter.Add(1)
			return nil
		},
		backoff.WithContext(backoff.NewConstantBackOff(proofPollingInterval), ctx),
	); err != nil {
		log.Error("Request proof error", "batchID", batch.BatchId, "error", err)
		return err
	}

	return nil
}

// SubmitProof implements the Submitter interface.
func (s *ProofSubmitterPacaya) SubmitProof(
	ctx context.Context,
	proofWithHeader *proofProducer.ProofWithHeader,
) (err error) {
	log.Info(
		"Submit batch proof",
		"batchID", proofWithHeader.Meta.TaikoBatchMetaDataPacaya().GetBatchID(),
		"coinbase", proofWithHeader.Meta.TaikoBatchMetaDataPacaya().GetCoinbase(),
		"proof", common.Bytes2Hex(proofWithHeader.Proof),
	)
	// Check if we still need to generate a new proof for that block.
	proofStatus, err := rpc.GetBatchProofStatus(
		ctx,
		s.rpc,
		proofWithHeader.Meta.TaikoBatchMetaDataPacaya().GetBatchID(),
	)
	if err != nil {
		return err
	}

	if proofStatus.IsSubmitted && !proofStatus.Invalid {
		return nil
	}

	metrics.ProverReceivedProofCounter.Add(1)

	// Build the TaikoInbox.proveBatches transaction and send it to the L1 node.
	if err = s.sender.Send(
		ctx,
		proofWithHeader,
		s.txBuilder.BuildProveBatchesPacaya(
			&proofProducer.BatchProofs{
				Proofs:     []*proofProducer.ProofWithHeader{proofWithHeader},
				BatchProof: proofWithHeader.Proof,
			},
		),
	); err != nil {
		if err.Error() == transaction.ErrUnretryableSubmission.Error() {
			return nil
		}
		metrics.ProverSubmissionErrorCounter.Add(1)
		return encoding.TryParsingCustomError(err)
	}

	metrics.ProverSentProofCounter.Add(1)
	metrics.ProverLatestProvenBlockIDGauge.Set(float64(proofWithHeader.BlockID.Uint64()))

	return nil
}

// BatchSubmitProofs implements the Submitter interface to submit proof aggregation.
func (s *ProofSubmitterPacaya) BatchSubmitProofs(ctx context.Context, batchProof *proofProducer.BatchProofs) error {
	return fmt.Errorf("batch proofs submission has not been implemented for Pacaya")
}

// AggregateProofs read all data from buffer and aggregate them.
func (s *ProofSubmitterPacaya) AggregateProofs(ctx context.Context) error {
	return fmt.Errorf("proof aggregation has not been implemented for Pacaya")
}

// Producer implements the Submitter interface.
func (s *ProofSubmitterPacaya) Producer() proofProducer.ProofProducer {
	return s.proofProducer
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
	return false
}
