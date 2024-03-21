package sender

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"
	"github.com/pborman/uuid"

	"github.com/taikoxyz/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

var (
	sendersMap                  = map[uint64]map[common.Address]*Sender{}
	unconfirmedTxsCap           = 100
	nonceIncorrectRetrys        = 3
	unconfirmedTxsCheckInternal = 2 * time.Second
	chainHeadFetchInterval      = 3 * time.Second
	errTimeoutInMempool         = errors.New("transaction in mempool for too long")
	errToManyPendings           = errors.New("too many pending transactions")
)

// Config represents the configuration of the transaction sender.
type Config struct {
	// The minimum block confirmations to wait to confirm a transaction.
	ConfirmationDepth uint64 `default:"0"`
	// The maximum retry times when sending transactions.
	MaxRetrys uint64 `default:"0"`
	// The maximum waiting time for the inclusion of transactions.
	MaxWaitingTime time.Duration `default:"5m"`
	// The gas limit for transactions.
	GasLimit uint64 `default:"0"`
	// The gas rate to increase the gas price, 20 means 20% gas growth rate.
	GasGrowthRate uint64 `default:"50"`
	// The maximum gas fee can be used when sending transactions.
	MaxGasFee uint64 `default:"0xffffffffffffffff"` // Use `math.MaxUint64` as default value
	// The maximum blob gas fee can be used when sending transactions.
	MaxBlobFee uint64 `default:"0xffffffffffffffff"` // Use `math.MaxUint64` as default value
}

// TxToConfirm represents a transaction which is waiting for its confirmation.
type TxToConfirm struct {
	confirmations uint64
	originalTx    types.TxData

	ID        string
	Retrys    uint64
	CurrentTx *types.Transaction
	Receipt   *types.Receipt
	CreatedAt time.Time

	Err error
}

// Sender represents a global transaction sender.
type Sender struct {
	ctx context.Context
	*Config

	head   *types.Header
	client *rpc.EthClient

	nonce uint64
	opts  *bind.TransactOpts

	unconfirmedTxs cmap.ConcurrentMap[string, *TxToConfirm]
	txToConfirmCh  cmap.ConcurrentMap[string, chan *TxToConfirm]

	mu     sync.Mutex
	wg     sync.WaitGroup
	stopCh chan struct{}
}

// NewSender creates a new instance of Sender.
func NewSender(ctx context.Context, cfg *Config, client *rpc.EthClient, priv *ecdsa.PrivateKey) (*Sender, error) {
	cfg = setConfigWithDefaultValues(cfg)

	// Create a new transactor
	opts, err := bind.NewKeyedTransactorWithChainID(priv, client.ChainID)
	if err != nil {
		return nil, err
	}
	// Do not automatically send transactions
	opts.NoSend = true
	opts.GasLimit = cfg.GasLimit

	// Add the sender to the root sender.
	if root := sendersMap[client.ChainID.Uint64()]; root == nil {
		sendersMap[client.ChainID.Uint64()] = map[common.Address]*Sender{}
	} else {
		if root[opts.From] != nil {
			return nil, fmt.Errorf("sender already exists")
		}
	}

	// Get the nonce
	nonce, err := client.NonceAt(ctx, opts.From, nil)
	if err != nil {
		return nil, err
	}

	// Get the chain ID
	head, err := client.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	sender := &Sender{
		ctx:            ctx,
		Config:         cfg,
		head:           head,
		client:         client,
		nonce:          nonce,
		opts:           opts,
		unconfirmedTxs: cmap.New[*TxToConfirm](),
		txToConfirmCh:  cmap.New[chan *TxToConfirm](),
		stopCh:         make(chan struct{}),
	}

	// Initialize the gas fee related fields
	if err = sender.updateGasTipGasFee(head); err != nil {
		return nil, err
	}
	if os.Getenv("RUN_TESTS") == "" {
		sendersMap[client.ChainID.Uint64()][opts.From] = sender
	}

	sender.wg.Add(1)
	go sender.loop()

	return sender, nil
}

// Close closes the sender.
func (s *Sender) Close() {
	close(s.stopCh)
	s.wg.Wait()
}

// GetOpts returns the transaction options of the sender.
func (s *Sender) GetOpts(ctx context.Context) *bind.TransactOpts {
	return &bind.TransactOpts{
		From:      s.opts.From,
		Nonce:     s.opts.Nonce,
		Signer:    s.opts.Signer,
		Value:     s.opts.Value,
		GasPrice:  s.opts.GasPrice,
		GasFeeCap: s.opts.GasFeeCap,
		GasTipCap: s.opts.GasTipCap,
		GasLimit:  s.opts.GasLimit,
		Context:   ctx,
		NoSend:    s.opts.NoSend,
	}
}

// Address returns the sender's address.
func (s *Sender) Address() common.Address {
	return s.opts.From
}

// TxToConfirmChannel returns a channel to wait the given transaction's confirmation.
func (s *Sender) TxToConfirmChannel(txID string) <-chan *TxToConfirm {
	ch, ok := s.txToConfirmCh.Get(txID)
	if !ok {
		log.Warn("Transaction not found", "id", txID)
	}
	return ch
}

// TxToConfirmChannels returns channels to wait the given transactions confirmation.
func (s *Sender) TxToConfirmChannels() map[string]<-chan *TxToConfirm {
	channels := map[string]<-chan *TxToConfirm{}
	for txID, confirmCh := range s.txToConfirmCh.Items() {
		channels[txID] = confirmCh
	}
	return channels
}

// GetUnconfirmedTx returns the unconfirmed transaction by the transaction ID.
func (s *Sender) GetUnconfirmedTx(txID string) *types.Transaction {
	txToConfirm, ok := s.unconfirmedTxs.Get(txID)
	if !ok {
		return nil
	}
	return txToConfirm.CurrentTx
}

// SendRawTransaction sends a transaction to the given Ethereum node.
func (s *Sender) SendRawTransaction(
	ctx context.Context,
	nonce uint64,
	target *common.Address,
	value *big.Int,
	data []byte,
	sidecar *types.BlobTxSidecar,
) (string, error) {
	// If there are too many pending transactions to be confirmed, return an error here.
	if s.unconfirmedTxs.Count() >= unconfirmedTxsCap {
		return "", errToManyPendings
	}
	if nonce == 0 {
		nonce = s.nonce
	}

	var (
		originalTx types.TxData
		opts       = s.GetOpts(ctx)
		gasLimit   = s.GasLimit
		err        error
	)
	if sidecar != nil {
		opts.Value = value
		if target == nil {
			target = &common.Address{}
		}
		blobTx, err := s.client.CreateBlobTx(opts, *target, data, sidecar)
		if err != nil {
			return "", err
		}
		blobTx.Nonce = nonce
		originalTx = blobTx
	} else {
		if gasLimit == 0 {
			if gasLimit, err = s.client.EstimateGas(s.ctx, ethereum.CallMsg{
				From:      opts.From,
				To:        target,
				Value:     value,
				Data:      data,
				GasTipCap: opts.GasTipCap,
				GasFeeCap: opts.GasFeeCap,
			}); err != nil {
				return "", err
			}
		}

		originalTx = &types.DynamicFeeTx{
			ChainID:   s.client.ChainID,
			To:        target,
			Nonce:     nonce,
			GasFeeCap: opts.GasFeeCap,
			GasTipCap: opts.GasTipCap,
			Gas:       gasLimit,
			Value:     value,
			Data:      data,
		}
	}

	txToConfirm := &TxToConfirm{originalTx: originalTx}

	if err := s.send(txToConfirm, false); err != nil && !strings.Contains(err.Error(), "replacement transaction") {
		log.Error(
			"Failed to send transaction",
			"txId", txToConfirm.ID,
			"nonce", nonce,
			"err", err,
		)
		return "", err
	}

	txID := txToConfirm.ID
	// Add the transaction to the unconfirmed transactions
	s.unconfirmedTxs.Set(txID, txToConfirm)
	s.txToConfirmCh.Set(txID, make(chan *TxToConfirm, 1))

	return txID, nil
}

// SendTransaction sends a transaction to the given Ethereum node.
func (s *Sender) SendTransaction(tx *types.Transaction) (string, error) {
	if s.unconfirmedTxs.Count() >= unconfirmedTxsCap {
		return "", errToManyPendings
	}

	txData, err := s.buildTxData(tx)
	if err != nil {
		return "", err
	}

	txToConfirm := &TxToConfirm{originalTx: txData, CurrentTx: tx}

	if err = s.send(txToConfirm, true); err != nil && !strings.Contains(err.Error(), "replacement transaction") {
		log.Error(
			"Failed to send transaction",
			"txId", txToConfirm.ID,
			"hash", tx.Hash(),
			"err", err,
		)
		return "", err
	}

	txID := txToConfirm.ID
	// Add the transaction to the unconfirmed transactions
	s.unconfirmedTxs.Set(txID, txToConfirm)
	s.txToConfirmCh.Set(txID, make(chan *TxToConfirm, 1))

	return txID, nil
}

// send is the internal method to send the real transaction.
func (s *Sender) send(tx *TxToConfirm, resetNonce bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Set the transaction ID and its creation time
	if tx.ID == "" {
		tx.ID = uuid.New()
		tx.CreatedAt = time.Now()
	}

	originalTx := tx.originalTx

	if resetNonce {
		// Set the nonce of the transaction.
		if err := s.SetNonce(originalTx, false); err != nil {
			return err
		}
	}

	for i := 0; i < nonceIncorrectRetrys; i++ {
		// Retry when nonce is incorrect
		rawTx, err := s.opts.Signer(s.opts.From, types.NewTx(originalTx))
		if err != nil {
			return err
		}
		tx.CurrentTx = rawTx
		err = s.client.SendTransaction(s.ctx, rawTx)
		tx.Err = err
		// Check if the error is nonce too low
		if err != nil {
			if strings.Contains(err.Error(), "nonce too low") {
				if err := s.SetNonce(originalTx, true); err != nil {
					log.Error(
						"Failed to set nonce when appear nonce too low",
						"txId", tx.ID,
						"nonce", tx.CurrentTx.Nonce(),
						"hash", rawTx.Hash(),
						"err", err,
					)
				} else {
					log.Warn(
						"Nonce is incorrect, retry sending the transaction with new nonce",
						"txId", tx.ID,
						"nonce", tx.CurrentTx.Nonce(),
						"hash", rawTx.Hash(),
						"err", err,
					)
				}
				continue
			}
			// handle the list:
			// ErrUnderpriced: "transaction underpriced"
			// ErrReplaceUnderpriced: "replacement transaction underpriced"
			// blob tx err at https://github.com/ethereum/go-ethereum/blob/
			// 20d3e0ac06ef2ad2f5f6500402edc5b6f0bf5b7c/core/txpool/blobpool/blobpool.go#L1157`
			if strings.Contains(err.Error(), "transaction underpriced") {
				if strings.Contains(err.Error(), "new tx blob gas fee cap") {
					s.AdjustBlobGasFee(originalTx)
				} else {
					s.AdjustGasFee(originalTx)
				}
				log.Warn(
					"Replacement transaction underpriced",
					"txId", tx.ID,
					"nonce", tx.CurrentTx.Nonce(),
					"hash", rawTx.Hash(),
					"err", err,
				)
				continue
			}
			log.Error(
				"Failed to send transaction",
				"txId", tx.ID,
				"nonce", tx.CurrentTx.Nonce(),
				"hash", rawTx.Hash(),
				"err", err,
			)
			return err
		}

		metrics.TxSenderSentCounter.Inc(1)
		break
	}
	s.nonce++
	return nil
}

// loop is the main event loop of the transaction sender.
func (s *Sender) loop() {
	defer s.wg.Done()

	chainHeadFetchTicker := time.NewTicker(chainHeadFetchInterval)
	defer chainHeadFetchTicker.Stop()

	unconfirmedTxsCheckTicker := time.NewTicker(unconfirmedTxsCheckInternal)
	defer unconfirmedTxsCheckTicker.Stop()

	for {
		select {
		case <-s.ctx.Done():
			return
		case <-s.stopCh:
			return
		case <-unconfirmedTxsCheckTicker.C:
			s.resendUnconfirmedTxs()
		case <-chainHeadFetchTicker.C:
			newHead, err := s.client.HeaderByNumber(s.ctx, nil)
			if err != nil {
				log.Error("Failed to get the latest header", "err", err)
				continue
			}
			if s.head.Hash() == newHead.Hash() {
				continue
			}
			s.head = newHead
			// Update the gas tip and gas fee
			if err = s.updateGasTipGasFee(newHead); err != nil {
				log.Warn("Failed to update gas tip and gas fee", "err", err)
			}
			// Check the unconfirmed transactions
			s.checkPendingTransactionsConfirmation()
		}
	}
}

// resendUnconfirmedTxs resends all unconfirmed transactions.
func (s *Sender) resendUnconfirmedTxs() {
	for id, unconfirmedTx := range s.unconfirmedTxs.Items() {
		if unconfirmedTx.Err == nil {
			continue
		}
		unconfirmedTx.Retrys++
		if s.MaxRetrys != 0 && unconfirmedTx.Retrys >= s.MaxRetrys {
			s.releaseUnconfirmedTx(id)
			continue
		}
		if err := s.send(unconfirmedTx, true); err != nil {
			metrics.TxSenderUnconfirmedCounter.Inc(1)
			log.Warn(
				"Failed to resend the transaction",
				"txId", id,
				"nonce", unconfirmedTx.CurrentTx.Nonce(),
				"hash", unconfirmedTx.CurrentTx.Hash(),
				"retrys", unconfirmedTx.Retrys,
				"err", err,
			)
		}
	}
}

// checkPendingTransactionsConfirmation checks the confirmation of the pending transactions.
func (s *Sender) checkPendingTransactionsConfirmation() {
	for id, pendingTx := range s.unconfirmedTxs.Items() {
		if pendingTx.Err != nil {
			continue
		}
		if pendingTx.Receipt == nil {
			// Ignore the transaction if it is pending.
			tx, isPending, err := s.client.TransactionByHash(s.ctx, pendingTx.CurrentTx.Hash())
			if err != nil {
				log.Warn(
					"Failed to fetch transaction",
					"txId", pendingTx.ID,
					"nonce", pendingTx.CurrentTx.Nonce(),
					"hash", pendingTx.CurrentTx.Hash(),
					"err", err,
				)
				continue
			}
			if isPending {
				// If the transaction is in mempool for too long, replace it.
				if time.Since(tx.Time()) > s.MaxWaitingTime {
					pendingTx.Err = errTimeoutInMempool
				}
				continue
			}
			// Get the transaction receipt.
			receipt, err := s.client.TransactionReceipt(s.ctx, pendingTx.CurrentTx.Hash())
			if err != nil {
				if err.Error() == "not found" {
					pendingTx.Err = err
					s.releaseUnconfirmedTx(id)
				}
				log.Warn("Failed to get the transaction receipt", "hash", pendingTx.CurrentTx.Hash(), "err", err)
				continue
			}

			// Record the gas fee metrics.
			if receipt.BlobGasUsed == 0 {
				metrics.TxSenderGasPriceGauge.Update(receipt.EffectiveGasPrice.Int64())
			} else {
				metrics.TxSenderBlobGasPriceGauge.Update(receipt.BlobGasPrice.Int64())
			}

			metrics.TxSenderTxIncludedTimeGauge.Update(int64(time.Since(pendingTx.CreatedAt).Seconds()))

			pendingTx.Receipt = receipt
			if receipt.Status != types.ReceiptStatusSuccessful {
				pendingTx.Err = fmt.Errorf("transaction status is failed, hash: %s", receipt.TxHash)
				metrics.TxSenderConfirmedFailedCounter.Inc(1)
				s.releaseUnconfirmedTx(id)
				continue
			}
		}
		pendingTx.confirmations = s.head.Number.Uint64() - pendingTx.Receipt.BlockNumber.Uint64()
		if pendingTx.confirmations >= s.ConfirmationDepth {
			metrics.TxSenderConfirmedSuccessfulCounter.Inc(1)
			s.releaseUnconfirmedTx(id)
		}
	}
}

// releaseUnconfirmedTx releases the unconfirmed transaction by the transaction ID.
func (s *Sender) releaseUnconfirmedTx(txID string) {
	txConfirm, _ := s.unconfirmedTxs.Get(txID)
	confirmCh, _ := s.txToConfirmCh.Get(txID)
	select {
	case confirmCh <- txConfirm:
	default:
	}
	// Remove the transaction from the unconfirmed transactions
	s.unconfirmedTxs.Remove(txID)
	s.txToConfirmCh.Remove(txID)
}
