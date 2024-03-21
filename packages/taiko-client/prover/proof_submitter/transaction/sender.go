package transaction

import (
	"context"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-client/pkg/sender"
	producer "github.com/taikoxyz/taiko-client/prover/proof_producer"
)

// Sender is responsible for sending proof submission transactions with a backoff policy.
type Sender struct {
	rpc         *rpc.Client
	innerSender *sender.Sender
}

// NewSender creates a new Sener instance.
func NewSender(
	cli *rpc.Client,
	txSender *sender.Sender,
) *Sender {
	return &Sender{
		rpc:         cli,
		innerSender: txSender,
	}
}

// Send sends the given proof to the TaikoL1 smart contract with a backoff policy.
func (s *Sender) Send(
	ctx context.Context,
	proofWithHeader *producer.ProofWithHeader,
	buildTx TxBuilder,
) error {
	// Check if this proof is still needed to be submitted.
	ok, err := s.validateProof(ctx, proofWithHeader)
	if err != nil || !ok {
		return err
	}

	// Assemble the TaikoL1.proveBlock transaction.
	tx, err := buildTx(s.innerSender.GetOpts(ctx))
	if err != nil {
		return err
	}

	// Send the transaction.
	id, err := s.innerSender.SendTransaction(tx)
	if err != nil {
		return err
	}

	// Waiting for the transaction to be confirmed.
	confirmationResult := <-s.innerSender.TxToConfirmChannel(id)
	if confirmationResult.Err != nil {
		log.Warn(
			"Failed to send TaikoL1.proveBlock transaction",
			"blockID", proofWithHeader.BlockID,
			"error", confirmationResult.Err,
		)
		return confirmationResult.Err
	}

	log.Info(
		"💰 Your block proof was accepted",
		"blockID", proofWithHeader.BlockID,
		"parentHash", proofWithHeader.Header.ParentHash,
		"hash", proofWithHeader.Header.Hash(),
		"stateRoot", proofWithHeader.Opts.StateRoot,
		"txHash", confirmationResult.CurrentTx.Hash(),
		"tier", proofWithHeader.Tier,
		"isContest", len(proofWithHeader.Proof) == 0,
	)

	metrics.ProverSubmissionAcceptedCounter.Inc(1)

	return nil
}

// validateProof checks if the proof's corresponding L1 block is still in the canonical chain and if the
// latest verified head is not ahead of this block proof.
func (s *Sender) validateProof(ctx context.Context, proofWithHeader *producer.ProofWithHeader) (bool, error) {
	// 1. Check if the corresponding L1 block is still in the canonical chain.
	l1Header, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(proofWithHeader.Meta.L1Height+1))
	if err != nil {
		log.Warn(
			"Failed to fetch L1 block",
			"blockID", proofWithHeader.BlockID,
			"l1Height", proofWithHeader.Meta.L1Height+1,
			"error", err,
		)
		return false, err
	}
	if l1Header.Hash() != proofWithHeader.Opts.EventL1Hash {
		log.Warn(
			"Reorg detected, skip the current proof submission",
			"blockID", proofWithHeader.BlockID,
			"l1Height", proofWithHeader.Meta.L1Height+1,
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
