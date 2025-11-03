package transaction

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	ethereum "github.com/ethereum/go-ethereum"
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
	privKey          *ecdsa.PrivateKey
	enableAccessList bool
}

// NewSender creates a new Sener instance.
func NewSender(
	cli *rpc.Client,
	txmgr txmgr.TxManager,
	privateTxmgr txmgr.TxManager,
	proverSetAddress common.Address,
	gasLimit uint64,
	privKey *ecdsa.PrivateKey,
	enableAccessList bool,
) *Sender {
	return &Sender{
		rpc:              cli,
		txmgrSelector:    utils.NewTxMgrSelector(txmgr, privateTxmgr, nil),
		proverSetAddress: proverSetAddress,
		gasLimit:         gasLimit,
		privKey:          privKey,
		enableAccessList: enableAccessList,
	}
}

// SendBatchProof sends the batch proof transaction to the L1 protocol.
func (s *Sender) SendBatchProof(ctx context.Context, buildTx TxBuilder, batchProof *producer.BatchProofs) error {
	txMgr, isPrivate := s.txmgrSelector.Select()

	// Assemble the transaction.
	txCandidate, err := buildTx(&bind.TransactOpts{GasLimit: s.gasLimit, Context: ctx, From: txMgr.From()})
	if err != nil {
		return err
	}

	// If tryAccessList is enabled, attempt to send with an access list first.
	if s.enableAccessList {
		if receipt, err := s.sendWithAccessList(ctx, txCandidate, txMgr.From()); err == nil {
			if receipt.Status != types.ReceiptStatusSuccessful {
				log.Error(
					"Failed to submit batch proofs (AL)",
					"txHash", receipt.TxHash,
					"isPrivateMempool", isPrivate,
					"error", encoding.TryParsingCustomErrorFromReceipt(ctx, s.rpc.L1, txMgr.From(), receipt),
				)
				metrics.ProverSubmissionRevertedCounter.Add(1)
				return ErrUnretryableSubmission
			}

			log.Info(
				fmt.Sprintf("🚚 Your %s batch proofs have been accepted (AL)", batchProof.ProofType),
				"txHash", receipt.TxHash,
				"blockIDs", batchProof.BatchIDs,
			)
			metrics.ProverSubmissionAcceptedCounter.Add(float64(len(batchProof.BatchIDs)))
			return nil
		} else {
			// Fall back to normal txmgr path
			log.Warn("Access-list proof send failed; falling back to txmgr", "err", err)
		}
	}

	// Default: Send via tx manager.
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

// sendWithAccessList constructs a DynamicFeeTx with a suggested access list and sends it,
// then waits for the receipt.
func (s *Sender) sendWithAccessList(ctx context.Context, candidate *txmgr.TxCandidate, from common.Address) (*types.Receipt, error) {
	if s.privKey == nil {
		return nil, errors.New("missing prover private key for AL send")
	}

	// Suggest fees
	txMgr, _ := s.txmgrSelector.Select()
	gasTipCap, baseFee, _, err := txMgr.SuggestGasPriceCaps(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get gas price caps: %w", err)
	}
	gasFeeCap := new(big.Int).Add(baseFee, gasTipCap)

	// Build CallMsg and access list
	value := candidate.Value
	if value == nil {
		value = common.Big0
	}
	msg := ethereum.CallMsg{
		From:  from,
		To:    candidate.To,
		Gas:   candidate.GasLimit,
		Value: value,
		Data:  candidate.TxData,
	}
	al, _, _, err := s.rpc.L1.CreateAccessList(ctx, msg)
	if err != nil {
		return nil, fmt.Errorf("createAccessList failed: %w", err)
	}

	// Determine gas limit: if none provided, estimate it; otherwise preflight call
	gasLimit := candidate.GasLimit
	if gasLimit == 0 {
		// Estimate gas for the call with the suggested access list attached
		if al != nil {
			msg.AccessList = *al
		}
		gas, err := s.rpc.L1.EstimateGas(ctx, msg)
		if err != nil {
			return nil, fmt.Errorf("failed to estimate gas: %w", err)
		}
		gasLimit = gas
	}

	// Resolve nonce
	nonce, err := s.rpc.L1.PendingNonceAt(ctx, from)
	if err != nil {
		return nil, fmt.Errorf("failed to get nonce: %w", err)
	}

	// Assemble dynamic fee tx with access list
	txdata := &types.DynamicFeeTx{
		ChainID:   s.rpc.L1.ChainID,
		Nonce:     nonce,
		To:        candidate.To,
		GasTipCap: gasTipCap,
		GasFeeCap: gasFeeCap,
		Gas:       gasLimit,
		Value:     value,
		Data:      candidate.TxData,
	}
	if al != nil {
		txdata.AccessList = *al
	}

	// Sign and send
	signer := types.NewCancunSigner(s.rpc.L1.ChainID)
	signed, err := types.SignNewTx(s.privKey, signer, txdata)
	if err != nil {
		return nil, fmt.Errorf("failed to sign tx: %w", err)
	}
	if err := s.rpc.L1.SendTransaction(ctx, signed); err != nil {
		return nil, fmt.Errorf("failed to send tx: %w", err)
	}

	// Wait for receipt
	deadline := time.Now().Add(2 * time.Minute)
	for {
		rc, err := s.rpc.L1.EthClient().TransactionReceipt(ctx, signed.Hash())
		if err == nil && rc != nil {
			return rc, nil
		}
		if err != nil && !errors.Is(err, ethereum.NotFound) {
			return nil, err
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timeout waiting for receipt: %s", signed.Hash())
		}
		time.Sleep(1 * time.Second)
	}
}
