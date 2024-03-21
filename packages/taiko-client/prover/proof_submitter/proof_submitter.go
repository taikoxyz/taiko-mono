package submitter

import (
	"context"
	"errors"
	"fmt"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-client/pkg/sender"
	validator "github.com/taikoxyz/taiko-client/prover/anchor_tx_validator"
	proofProducer "github.com/taikoxyz/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-client/prover/proof_submitter/transaction"
)

var _ Submitter = (*ProofSubmitter)(nil)

// ProofSubmitter is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoL1 smart contract.
type ProofSubmitter struct {
	rpc             *rpc.Client
	proofProducer   proofProducer.ProofProducer
	resultCh        chan *proofProducer.ProofWithHeader
	anchorValidator *validator.AnchorTxValidator
	txBuilder       *transaction.ProveBlockTxBuilder
	sender          *transaction.Sender
	proverAddress   common.Address
	taikoL2Address  common.Address
	graffiti        [32]byte
}

// NewProofSubmitter creates a new ProofSubmitter instance.
func NewProofSubmitter(
	rpcClient *rpc.Client,
	proofProducer proofProducer.ProofProducer,
	resultCh chan *proofProducer.ProofWithHeader,
	taikoL2Address common.Address,
	graffiti string,
	txSender *sender.Sender,
	builder *transaction.ProveBlockTxBuilder,
) (*ProofSubmitter, error) {
	anchorValidator, err := validator.New(taikoL2Address, rpcClient.L2.ChainID, rpcClient)
	if err != nil {
		return nil, err
	}

	return &ProofSubmitter{
		rpc:             rpcClient,
		proofProducer:   proofProducer,
		resultCh:        resultCh,
		anchorValidator: anchorValidator,
		txBuilder:       builder,
		sender:          transaction.NewSender(rpcClient, txSender),
		proverAddress:   txSender.Address(),
		taikoL2Address:  taikoL2Address,
		graffiti:        rpc.StringToBytes32(graffiti),
	}, nil
}

// RequestProof implements the Submitter interface.
func (s *ProofSubmitter) RequestProof(ctx context.Context, event *bindings.TaikoL1ClientBlockProposed) error {
	l1Origin, err := s.rpc.WaitL1Origin(ctx, event.BlockId)
	if err != nil {
		return fmt.Errorf("failed to fetch l1Origin, blockID: %d, err: %w", event.BlockId, err)
	}

	// Get the header of the block to prove from L2 execution engine.
	block, err := s.rpc.L2.BlockByHash(ctx, l1Origin.L2BlockHash)
	if err != nil {
		return fmt.Errorf("failed to get the current L2 block by hash (%s): %w", l1Origin.L2BlockHash, err)
	}

	if block.Transactions().Len() == 0 {
		return errors.New("no transaction in block")
	}

	parent, err := s.rpc.L2.BlockByHash(ctx, block.ParentHash())
	if err != nil {
		return fmt.Errorf("failed to get the L2 parent block by hash (%s): %w", block.ParentHash(), err)
	}

	blockInfo, err := s.rpc.GetL2BlockInfo(ctx, event.BlockId)
	if err != nil {
		return err
	}

	// Request proof.
	opts := &proofProducer.ProofRequestOptions{
		BlockID:            block.Number(),
		ProverAddress:      s.proverAddress,
		ProposeBlockTxHash: event.Raw.TxHash,
		TaikoL2:            s.taikoL2Address,
		MetaHash:           blockInfo.Blk.MetaHash,
		BlockHash:          block.Hash(),
		ParentHash:         block.ParentHash(),
		StateRoot:          block.Root(),
		EventL1Hash:        event.Raw.BlockHash,
		Graffiti:           common.Bytes2Hex(s.graffiti[:]),
		GasUsed:            block.GasUsed(),
		ParentGasUsed:      parent.GasUsed(),
	}

	// Send the generated proof.
	result, err := s.proofProducer.RequestProof(
		ctx,
		opts,
		event.BlockId,
		&event.Meta,
		block.Header(),
	)
	if err != nil {
		return fmt.Errorf("failed to request proof (id: %d): %w", event.BlockId, err)
	}
	s.resultCh <- result

	metrics.ProverQueuedProofCounter.Inc(1)

	return nil
}

// SubmitProof implements the Submitter interface.
func (s *ProofSubmitter) SubmitProof(
	ctx context.Context,
	proofWithHeader *proofProducer.ProofWithHeader,
) (err error) {
	log.Info(
		"NewProofSubmitter block proof",
		"blockID", proofWithHeader.BlockID,
		"proposer", proofWithHeader.Meta.Coinbase,
		"parentHash", proofWithHeader.Header.ParentHash,
		"hash", proofWithHeader.Opts.BlockHash,
		"stateRoot", proofWithHeader.Opts.StateRoot,
		"proof", common.Bytes2Hex(proofWithHeader.Proof),
		"tier", proofWithHeader.Tier,
	)

	metrics.ProverReceivedProofCounter.Inc(1)

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

	// Get and validate this anchor transaction's receipt.
	if _, err = s.anchorValidator.GetAndValidateAnchorTxReceipt(ctx, anchorTx); err != nil {
		return fmt.Errorf("failed to fetch anchor transaction receipt: %w", err)
	}

	// Build the TaikoL1.proveBlock transaction and send it to the L1 node.
	if err = encoding.TryParsingCustomError(s.sender.Send(
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
			proofWithHeader.Tier == encoding.TierGuardianID,
		),
	)); err != nil {
		if err.Error() == transaction.ErrUnretryableSubmission.Error() {
			return nil
		}
		metrics.ProverSubmissionErrorCounter.Inc(1)
		return err
	}

	metrics.ProverSentProofCounter.Inc(1)
	metrics.ProverLatestProvenBlockIDGauge.Update(proofWithHeader.BlockID.Int64())

	return nil
}

// Producer returns the inner proof producer.
func (s *ProofSubmitter) Producer() proofProducer.ProofProducer {
	return s.proofProducer
}

// Tier returns the proof tier of the current proof submitter.
func (s *ProofSubmitter) Tier() uint16 {
	return s.proofProducer.Tier()
}
