package transaction

import (
	"context"
	"fmt"
	"math/big"

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

// SendBatchProof sends the batch proof transaction to the L1 protocol.
func (s *Sender) SendBatchProof(ctx context.Context, buildTx TxBuilder, batchProof *producer.BatchProofs) error {
	txMgr, isPrivate := s.txmgrSelector.Select()

	// Assemble the Pacaya TaikoInbox.proveBatches transaction.
	txCandidate, err := buildTx(&bind.TransactOpts{GasLimit: s.gasLimit, Context: ctx, From: txMgr.From()})
	if err != nil {
		return err
	}

	// Send the transaction.
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
		fmt.Sprintf("🚚 Your %s batch proofs have been accepted", batchProof.ProofType),
		"txHash", receipt.TxHash,
		"blockIDs", batchProof.BatchIDs,
	)

	metrics.ProverSubmissionAcceptedCounter.Add(float64(len(batchProof.BatchIDs)))

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
			"blockID", proofResponse.BatchID,
			"l1Height", proofResponse.Meta.GetRawBlockHeight(),
			"error", err,
		)
		return false, err
	}
	if l1Header.Hash() != proofResponse.Opts.GetRawBlockHash() {
		log.Warn(
			"Reorg detected, skip the current proof submission",
			"blockID", proofResponse.BatchID,
			"l1Height", proofResponse.Meta.GetRawBlockHeight(),
			"l1HashOld", proofResponse.Opts.GetRawBlockHash(),
			"l1HashNew", l1Header.Hash(),
		)
		return false, nil
	}

	var verifiedID = latestVerifiedID
	// 2. Check if latest verified head is ahead of the current block.
	if verifiedID == nil {
		ts, err := s.rpc.GetLastVerifiedTransitionPacaya(ctx)
		if err != nil {
			return false, err
		}
		verifiedID = new(big.Int).SetUint64(ts.BlockId)
	}

	if verifiedID.Cmp(new(big.Int).SetUint64(proofResponse.Meta.Pacaya().GetLastBlockID())) >= 0 {
		log.Info(
			"Batch is already verified, skip current proof submission",
			"batchID", proofResponse.Meta.Pacaya().GetBatchID(),
			"latestVerifiedID", latestVerifiedID,
		)
		return false, nil
	}

	return true, nil
}
