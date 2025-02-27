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
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// Sender is responsible for sending proof submission transactions with a backoff policy.
type Sender struct {
	rpc              *rpc.Client
	txmgrSelector    *utils.TxMgrSelector
	proverSetAddress common.Address
	gasLimit         uint64
}

// NewSender creates a new Sener instance.
func NewSender(
	cli *rpc.Client,
	txmgr txmgr.TxManager,
	privateTxmgr txmgr.TxManager,
	proverSetAddress common.Address,
	gasLimit uint64,
) *Sender {
	return &Sender{
		rpc:              cli,
		txmgrSelector:    utils.NewTxMgrSelector(txmgr, privateTxmgr, nil),
		proverSetAddress: proverSetAddress,
		gasLimit:         gasLimit,
	}
}

func getProofTypeString(tier uint16) string {
	switch tier {
	case encoding.TierOptimisticID:
		return "Optimistic"
	case encoding.TierSgxID:
		return "SGX"
	case encoding.TierZkVMRisc0ID:
		return "ZK-RISC0"
	case encoding.TierZkVMSp1ID:
		return "ZK-SP1"
	case encoding.TierSgxAndZkVMID:
		return "SGX+ZK"
	case encoding.TierGuardianMinorityID:
		return "Guardian-Minority"
	case encoding.TierGuardianMajorityID:
		return "Guardian-Majority"
	default:
		return "Unknown"
	}
}

// Send sends the given proof to the TaikoL1 smart contract with a backoff policy.
func (s *Sender) Send(
	ctx context.Context,
	proofResponse *producer.ProofResponse,
	buildTx TxBuilder,
) (err error) {
	var proofStatus *rpc.BlockProofStatus

	// Check if the proof has already been submitted.
	if proofResponse.Meta.IsPacaya() {
		if proofStatus, err = rpc.GetBatchProofStatus(
			ctx,
			s.rpc,
			proofResponse.Meta.Pacaya().GetBatchID(),
		); err != nil {
			return err
		}
	} else {
		if proofStatus, err = rpc.GetBlockProofStatus(
			ctx,
			s.rpc,
			proofResponse.BlockID,
			proofResponse.Opts.GetProverAddress(),
			s.proverSetAddress,
		); err != nil {
			return err
		}
	}

	if proofStatus.IsSubmitted && !proofStatus.Invalid {
		return fmt.Errorf("a valid proof for block %d is already submitted", proofResponse.BlockID)
	}

	// Check if this proof is still needed to be submitted.
	ok, err := s.ValidateProof(ctx, proofResponse, nil)
	if err != nil || !ok {
		return err
	}

	// Assemble the TaikoL1.proveBlock transaction.
	txCandidate, err := buildTx(&bind.TransactOpts{GasLimit: s.gasLimit})
	if err != nil {
		return err
	}

	// Send the transaction.
	txMgr, isPrivate := s.txmgrSelector.Select()
	receipt, err := txMgr.Send(ctx, *txCandidate)
	if err != nil {
		if isPrivate {
			s.txmgrSelector.RecordPrivateTxMgrFailed()
		}
		return encoding.TryParsingCustomError(err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Error(
			"Failed to submit proof",
			"blockID", proofResponse.BlockID,
			"tier", proofResponse.Tier,
			"proofType", proofResponse.ProofType,
			"txHash", receipt.TxHash,
			"isPrivateMempool", isPrivate,
			"error", encoding.TryParsingCustomErrorFromReceipt(ctx, s.rpc.L1, txMgr.From(), receipt),
		)
		metrics.ProverSubmissionRevertedCounter.Add(1)
		return ErrUnretryableSubmission
	}

	if proofResponse.Meta.IsPacaya() {
		log.Info(
			"💰 Your batch proof was accepted",
			"batchID", proofResponse.Meta.Pacaya().GetBatchID(),
			"blocks", len(proofResponse.Meta.Pacaya().GetBlocks()),
		)
	} else {
		log.Info(
			"💰 Your block proof was accepted",
			"blockID", proofResponse.BlockID,
			"parentHash", proofResponse.Opts.OntakeOptions().ParentHash,
			"hash", proofResponse.Opts.OntakeOptions().BlockHash,
			"txHash", receipt.TxHash,
			"tier", proofResponse.Tier,
			"proofType", proofResponse.ProofType,
			"isContest", len(proofResponse.Proof) == 0,
		)
	}

	metrics.ProverSubmissionAcceptedCounter.Add(1)

	return nil
}

func (s *Sender) SendBatchProof(
	ctx context.Context,
	buildTx TxBuilder,
	batchProof *producer.BatchProofs,
) error {
	// Assemble the TaikoL1.proveBlocks transaction.
	txCandidate, err := buildTx(&bind.TransactOpts{GasLimit: s.gasLimit})
	if err != nil {
		return err
	}
	// Send the transaction.
	txMgr, isPrivate := s.txmgrSelector.Select()
	receipt, err := txMgr.Send(ctx, *txCandidate)
	if err != nil {
		if isPrivate {
			s.txmgrSelector.RecordPrivateTxMgrFailed()
		}
		return encoding.TryParsingCustomError(err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Error(
			"Failed to submit batch proofs",
			"txHash", receipt.TxHash,
			"isPrivateMempool", isPrivate,
			"error", encoding.TryParsingCustomErrorFromReceipt(ctx, s.rpc.L1, txMgr.From(), receipt),
		)
		metrics.ProverSubmissionRevertedCounter.Add(1)
		return ErrUnretryableSubmission
	}

	log.Info(
		fmt.Sprintf("🚚 Your %s batch proofs were accepted", getProofTypeString(batchProof.Tier)),
		"txHash", receipt.TxHash,
		"tier", batchProof.Tier,
		"blockIDs", batchProof.BlockIDs,
	)

	metrics.ProverSubmissionAcceptedCounter.Add(float64(len(batchProof.BlockIDs)))

	return nil
}

// ValidateProof checks if the proof's corresponding L1 block is still in the canonical chain and if the
// latest verified head is not ahead of this block proof.
func (s *Sender) ValidateProof(
	ctx context.Context,
	proofResponse *producer.ProofResponse,
	latestVerifiedID *big.Int,
) (bool, error) {
	// 1. Check if the corresponding L1 block is still in the canonical chain.
	l1Header, err := s.rpc.L1.HeaderByNumber(ctx, proofResponse.Meta.GetRawBlockHeight())
	if err != nil {
		log.Warn(
			"Failed to fetch L1 block",
			"blockID", proofResponse.BlockID,
			"l1Height", proofResponse.Meta.GetRawBlockHeight(),
			"error", err,
		)
		return false, err
	}
	if l1Header.Hash() != proofResponse.Opts.GetRawBlockHash() {
		log.Warn(
			"Reorg detected, skip the current proof submission",
			"blockID", proofResponse.BlockID,
			"l1Height", proofResponse.Meta.GetRawBlockHeight(),
			"l1HashOld", proofResponse.Opts.GetRawBlockHash(),
			"l1HashNew", l1Header.Hash(),
		)
		return false, nil
	}

	var verifiedID = latestVerifiedID
	// 2. Check if latest verified head is ahead of this block proof.
	if verifiedID == nil {
		ts, err := s.rpc.GetLastVerifiedTransitionPacaya(ctx)
		if err != nil {
			blockInfo, err := s.rpc.GetLastVerifiedBlockOntake(ctx)
			if err != nil {
				return false, err
			}
			verifiedID = new(big.Int).SetUint64(blockInfo.BlockId)
		} else {
			verifiedID = new(big.Int).SetUint64(ts.BlockId)
		}
	}

	if proofResponse.Meta.IsPacaya() {
		if verifiedID.Cmp(new(big.Int).SetUint64(proofResponse.Meta.Pacaya().GetLastBlockID())) >= 0 {
			log.Info(
				"Batch is already verified, skip current proof submission",
				"batchID", proofResponse.Meta.Pacaya().GetBatchID(),
				"latestVerifiedID", latestVerifiedID,
			)
			return false, nil
		}
	} else {
		if verifiedID.Cmp(proofResponse.BlockID) >= 0 {
			log.Info(
				"Block is already verified, skip current proof submission",
				"blockID", proofResponse.BlockID.Uint64(),
				"latestVerifiedID", latestVerifiedID,
			)
			return false, nil
		}
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
