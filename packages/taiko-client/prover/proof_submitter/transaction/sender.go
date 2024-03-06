package transaction

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-client/pkg/rpc"

	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/internal/metrics"
	producer "github.com/taikoxyz/taiko-client/prover/proof_producer"
)

var (
	ErrUnretryable = errors.New("unretryable")
)

// Sender is responsible for sending proof submission transactions with a backoff policy, if
// the transaction should not be retried anymore, it will return an `ErrUnretryable` error.
type Sender struct {
	rpc                *rpc.Client
	backOffPolicy      backoff.BackOff
	maxRetry           *uint64
	waitReceiptTimeout time.Duration
}

// NewSender creates a new Sener instance.
func NewSender(
	cli *rpc.Client,
	retryInterval time.Duration,
	maxRetry *uint64,
	waitReceiptTimeout time.Duration,
) *Sender {
	var backOffPolicy backoff.BackOff = backoff.NewConstantBackOff(retryInterval)
	if maxRetry != nil {
		backOffPolicy = backoff.WithMaxRetries(backOffPolicy, *maxRetry)
	}

	return &Sender{
		rpc:                cli,
		backOffPolicy:      backOffPolicy,
		maxRetry:           maxRetry,
		waitReceiptTimeout: waitReceiptTimeout,
	}
}

// Send sends the given proof to the TaikoL1 smart contract with a backoff policy, if
// the transaction should not be retried anymore, it will return an `ErrUnretryable` error.
func (s *Sender) Send(
	ctx context.Context,
	proofWithHeader *producer.ProofWithHeader,
	buildTx TxBuilder,
) error {
	var (
		isUnretryableError bool
		nonce              *big.Int
	)

	if err := backoff.Retry(func() error {
		if ctx.Err() != nil {
			return nil
		}

		// Check if this proof is still needed to be submitted.
		ok, err := s.validateProof(ctx, proofWithHeader)
		if err != nil {
			return err
		}
		if !ok {
			return nil
		}

		// Assemble the taikoL1.proveBlock transaction.
		tx, err := buildTx(nonce)
		if err != nil {
			err = encoding.TryParsingCustomError(err)
			if isSubmitProofTxErrorRetryable(err, proofWithHeader.BlockID) {
				log.Warn("Retry sending TaikoL1.proveBlock transaction", "blockID", proofWithHeader.BlockID, "reason", err)
				if errors.Is(err, core.ErrNonceTooLow) {
					nonce = nil
				}

				return err
			}

			isUnretryableError = true
			return nil
		}

		// Wait for the transaction receipt.
		ctxWithTimeout, cancel := context.WithTimeout(ctx, s.waitReceiptTimeout)
		defer cancel()

		if _, err := rpc.WaitReceipt(ctxWithTimeout, s.rpc.L1, tx); err != nil {
			log.Warn(
				"Failed to wait till transaction executed",
				"blockID", proofWithHeader.BlockID,
				"txHash", tx.Hash(),
				"error", err,
			)
			return err
		}

		log.Info(
			"💰 Your block proof was accepted",
			"blockID", proofWithHeader.BlockID,
			"parentHash", proofWithHeader.Header.ParentHash,
			"hash", proofWithHeader.Header.Hash(),
			"stateRoot", proofWithHeader.Opts.StateRoot,
			"txHash", tx.Hash(),
			"tier", proofWithHeader.Tier,
			"isContest", len(proofWithHeader.Proof) == 0,
		)

		metrics.ProverSubmissionAcceptedCounter.Inc(1)

		return nil
	}, s.backOffPolicy); err != nil {
		if s.maxRetry != nil {
			log.Error("Failed to send TaikoL1.proveBlock transaction", "error", err, "maxRetry", *s.maxRetry)
			return ErrUnretryable
		}
		return fmt.Errorf("failed to send TaikoL1.proveBlock transaction: %w", err)
	}

	if isUnretryableError {
		return ErrUnretryable
	}

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
	if !strings.HasPrefix(err.Error(), "L1_") && !strings.HasPrefix(err.Error(), "PROVING_FAILED") {
		return true
	}

	log.Warn("🤷 Unretryable proof submission error", "error", err, "blockID", blockID)
	return false
}
