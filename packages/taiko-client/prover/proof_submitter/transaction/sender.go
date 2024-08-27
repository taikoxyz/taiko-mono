package transaction

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// Sender is responsible for sending proof submission transactions with a backoff policy.
type Sender struct {
	rpc              *rpc.Client
	txmgr            *txmgr.SimpleTxManager
	privateTxmgr     *txmgr.SimpleTxManager
	proverSetAddress common.Address
	gasLimit         uint64
}

// NewSender creates a new Sener instance.
func NewSender(
	cli *rpc.Client,
	txmgr *txmgr.SimpleTxManager,
	privateTxmgr *txmgr.SimpleTxManager,
	proverSetAddress common.Address,
	gasLimit uint64,
) *Sender {
	return &Sender{
		rpc:              cli,
		txmgr:            txmgr,
		privateTxmgr:     privateTxmgr,
		proverSetAddress: proverSetAddress,
		gasLimit:         gasLimit,
	}
}

// Send sends the given proof to the TaikoL1 smart contract with a backoff policy.
func (s *Sender) Send(
	ctx context.Context,
	proofWithHeader *producer.ProofWithHeader,
	buildTx TxBuilder,
) error {
	// Check if the proof has already been submitted.
	proofStatus, err := rpc.GetBlockProofStatus(
		ctx,
		s.rpc,
		proofWithHeader.BlockID,
		proofWithHeader.Opts.ProverAddress,
		s.proverSetAddress,
	)
	if err != nil {
		return err
	}
	if proofStatus.IsSubmitted && !proofStatus.Invalid {
		return fmt.Errorf("a valid proof for block %d is already submitted", proofWithHeader.BlockID)
	}

	// Check if this proof is still needed to be submitted.
	ok, err := s.validateProof(ctx, proofWithHeader)
	if err != nil || !ok {
		return err
	}

	// Assemble the TaikoL1.proveBlock transaction.
	txCandidate, err := buildTx(&bind.TransactOpts{GasLimit: s.gasLimit})
	if err != nil {
		return err
	}

	// Send the transaction.
	var (
		txMgr   = s.txmgr
		receipt *types.Receipt
	)
	if s.privateTxmgr != nil {
		txMgr = s.privateTxmgr
	}
	if receipt, err = txMgr.Send(ctx, *txCandidate); err != nil {
		return encoding.TryParsingCustomError(err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Error(
			"Failed to submit proof",
			"blockID", proofWithHeader.BlockID,
			"tier", proofWithHeader.Tier,
			"txHash", receipt.TxHash,
			"isPrivateTxMgr", s.privateTxmgr != nil,
			"error", encoding.TryParsingCustomErrorFromReceipt(ctx, s.rpc.L1, s.txmgr.From(), receipt),
		)
		metrics.ProverSubmissionRevertedCounter.Add(1)
		return ErrUnretryableSubmission
	}

	log.Info(
		"💰 Your block proof was accepted",
		"blockID", proofWithHeader.BlockID,
		"parentHash", proofWithHeader.Header.ParentHash,
		"hash", proofWithHeader.Header.Hash(),
		"stateRoot", proofWithHeader.Opts.StateRoot,
		"txHash", receipt.TxHash,
		"tier", proofWithHeader.Tier,
		"isContest", len(proofWithHeader.Proof) == 0,
	)

	metrics.ProverSubmissionAcceptedCounter.Add(1)

	return nil
}

// validateProof checks if the proof's corresponding L1 block is still in the canonical chain and if the
// latest verified head is not ahead of this block proof.
func (s *Sender) validateProof(ctx context.Context, proofWithHeader *producer.ProofWithHeader) (bool, error) {
	// 1. Check if the corresponding L1 block is still in the canonical chain.
	l1Header, err := s.rpc.L1.HeaderByNumber(ctx, proofWithHeader.Meta.GetRawBlockHeight())
	if err != nil {
		log.Warn(
			"Failed to fetch L1 block",
			"blockID", proofWithHeader.BlockID,
			"l1Height", proofWithHeader.Meta.GetRawBlockHeight(),
			"error", err,
		)
		return false, err
	}
	if l1Header.Hash() != proofWithHeader.Opts.EventL1Hash {
		log.Warn(
			"Reorg detected, skip the current proof submission",
			"blockID", proofWithHeader.BlockID,
			"l1Height", proofWithHeader.Meta.GetRawBlockHeight(),
			"l1HashOld", proofWithHeader.Opts.EventL1Hash,
			"l1HashNew", l1Header.Hash(),
		)
		return false, nil
	}

	// 2. Check if latest verified head is ahead of this block proof.
	stateVars, err := s.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Warn(
			"Failed to fetch state variables",
			"blockID", proofWithHeader.BlockID,
			"error", err,
		)
		return false, err
	}
	latestVerifiedID := stateVars.B.LastVerifiedBlockId
	if new(big.Int).SetUint64(latestVerifiedID).Cmp(proofWithHeader.BlockID) >= 0 {
		log.Info(
			"Block is already verified, skip current proof submission",
			"blockID", proofWithHeader.BlockID.Uint64(),
			"latestVerifiedID", latestVerifiedID,
		)
		return false, nil
	}

	return true, nil
}

// isSubmitProofTxErrorRetryable checks whether the error returned by a proof submission transaction
// is retryable.
func isSubmitProofTxErrorRetryable(err error, blockID *big.Int) bool {
	if !strings.HasPrefix(err.Error(), "L1_") {
		return true
	}

	if strings.HasPrefix(err.Error(), "L1_NOT_ASSIGNED_PROVER") ||
		strings.HasPrefix(err.Error(), "L1_INVALID_PAUSE_STATUS") {
		return true
	}

	log.Warn("🤷 Unretryable proof submission error", "error", err, "blockID", blockID)
	return false
}
