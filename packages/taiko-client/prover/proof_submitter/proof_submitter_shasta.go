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

// ProofSubmitterPacaya is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoInbox smart contract.
type ProofSubmitterShasta struct {
	rpc *rpc.Client
	// Proof producers
	opProofProducer proofProducer.ProofProducer
	// Channels
	batchResultCh     chan *proofProducer.BatchProofs
	proofSubmissionCh chan *proofProducer.ProofRequestBody
	// Utilities
	txBuilder *transaction.ProveBatchesTxBuilder
	sender    *transaction.Sender
	indexer   *shastaIndexer.Indexer
	// Addresses
	proverAddress common.Address
	// Intervals
	proofPollingInterval time.Duration
}

// NewProofSubmitterShasta creates a new Shasta ProofSubmitter instance.
func NewProofSubmitterShasta(
	opProver proofProducer.ProofProducer,
	batchResultCh chan *proofProducer.BatchProofs,
	proofSubmissionCh chan *proofProducer.ProofRequestBody,
	indexer *shastaIndexer.Indexer,
	senderOpts *SenderOptions,
	builder *transaction.ProveBatchesTxBuilder,
	proofPollingInterval time.Duration,
) (*ProofSubmitterShasta, error) {
	return &ProofSubmitterShasta{
		rpc:               senderOpts.RPCClient,
		opProofProducer:   opProver,
		batchResultCh:     batchResultCh,
		proofSubmissionCh: proofSubmissionCh,
		indexer:           indexer,
		txBuilder:         builder,
		sender: transaction.NewSender(
			senderOpts.RPCClient,
			senderOpts.Txmgr,
			senderOpts.PrivateTxmgr,
			senderOpts.ProverSetAddress,
			senderOpts.GasLimit,
		),
		proverAddress:        senderOpts.Txmgr.From(),
		proofPollingInterval: proofPollingInterval,
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

	// Request proof.
	var (
		opts = &proofProducer.ProofRequestOptionsShasta{
			BatchID:       meta.Shasta().GetProposal().Id,
			ProverAddress: s.proverAddress,
			EventL1Hash:   meta.GetRawBlockHash(),
			Headers:       []*types.Header{header},
		}
		startAt       = time.Now()
		proofResponse *proofProducer.ProofResponse
	)

	// Send the generated proof.
	if err := backoff.Retry(func() error {
		if ctx.Err() != nil {
			log.Error("Failed to request proof, context is canceled", "batchID", opts.BatchID, "error", ctx.Err())
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

		if proofResponse, err = s.opProofProducer.RequestProof(
			ctx,
			opts,
			meta.Shasta().GetProposal().Id,
			meta,
			startAt,
		); err != nil {
			return fmt.Errorf("failed to request proof: %w", err)
		}

		log.Info(
			"Proof generated successfully for Shasta batch",
			"batchID", meta.Shasta().GetProposal().Id,
			"proofType", proofResponse.ProofType,
		)

		return nil
	}, backoff.WithContext(backoff.NewConstantBackOff(s.proofPollingInterval), ctx)); err != nil {
		if !errors.Is(err, proofProducer.ErrZkAnyNotDrawn) &&
			!errors.Is(err, proofProducer.ErrProofInProgress) &&
			!errors.Is(err, proofProducer.ErrRetry) {
			log.Error("Failed to request a Shasta proof", "batchID", meta.Shasta().GetProposal().Id, "error", err)
		} else {
			log.Debug("Expected Pacaya proof generation error", "error", err, "batchID", meta.Shasta().GetProposal().Id)
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
	// Build the Shata Inbox.prove transaction and send it to the L1 node.
	if err := s.sender.SendBatchProof(
		ctx,
		s.txBuilder.BuildProveBatchesShasta(batchProof),
		batchProof,
	); err != nil {
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

	lastHeader := batchProof.ProofResponses[len(batchProof.ProofResponses)-1].Opts.ShastaOptions().
		Headers[len(batchProof.ProofResponses[len(batchProof.ProofResponses)-1].Opts.ShastaOptions().Headers)-1]

	metrics.ProverLatestProvenBlockIDGauge.Set(float64(lastHeader.Number.Uint64()))

	return nil
}

// AggregateProofsByType aggregates proofs of the specified type and submits them in a batch.
func (s *ProofSubmitterShasta) AggregateProofsByType(ctx context.Context, proofType proofProducer.ProofType) error {
	return errors.New("not implemented")
}
