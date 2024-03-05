package sender

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"
	"github.com/pborman/uuid"

	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

var (
	sendersMap                  = map[uint64]map[common.Address]*Sender{}
	unconfirmedTxsCap           = 100
	nonceIncorrectRetrys        = 3
	unconfirmedTxsCheckInternal = 2 * time.Second
	chainHeadFetchInterval      = 3 * time.Second
	errTimeoutInMempool         = fmt.Errorf("transaction in mempool for too long")
	DefaultConfig               = &Config{
		ConfirmationDepth: 0,
		MaxRetrys:         0,
		MaxWaitingTime:    5 * time.Minute,
		GasGrowthRate:     50,
		MaxGasFee:         math.MaxUint64,
		MaxBlobFee:        math.MaxUint64,
	}
)

// Config represents the configuration of the transaction sender.
type Config struct {
	// The minimum block confirmations to wait to confirm a transaction.
	ConfirmationDepth uint64
	// The maximum retry times when sending transactions.
	MaxRetrys uint64
	// The maximum waiting time for the inclusion of transactions.
	MaxWaitingTime time.Duration

	// The gas limit for transactions.
	GasLimit uint64
	// The gas rate to increase the gas price, 20 means 20% gas growth rate.
	GasGrowthRate uint64
	// The maximum gas fee can be used when sending transactions.
	MaxGasFee  uint64
	MaxBlobFee uint64
}

// TxToConfirm represents a transaction which is waiting for its confirmation.
type TxToConfirm struct {
	confirmations uint64
	originalTx    types.TxData

	ID        string
	Retrys    uint64
	CurrentTx *types.Transaction
	Receipt   *types.Receipt

	Err error
}

// Sender represents a global transaction sender.
type Sender struct {
	ctx context.Context
	*Config

	head   *types.Header
	client *rpc.EthClient

	Opts *bind.TransactOpts

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
		Opts:           opts,
		unconfirmedTxs: cmap.New[*TxToConfirm](),
		txToConfirmCh:  cmap.New[chan *TxToConfirm](),
		stopCh:         make(chan struct{}),
	}
	// Initialize the nonce
	sender.AdjustNonce(nil)

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

func (s *Sender) Close() {
	close(s.stopCh)
	s.wg.Wait()
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
func (s *Sender) SendRawTransaction(nonce uint64, target *common.Address, value *big.Int, data []byte) (string, error) {
	gasLimit := s.GasLimit
	if gasLimit == 0 {
		var err error
		gasLimit, err = s.client.EstimateGas(s.ctx, ethereum.CallMsg{
			From:      s.Opts.From,
			To:        target,
			Value:     value,
			Data:      data,
			GasTipCap: s.Opts.GasTipCap,
			GasFeeCap: s.Opts.GasFeeCap,
		})
		if err != nil {
			return "", err
		}
	}
	return s.SendTransaction(types.NewTx(&types.DynamicFeeTx{
		ChainID:   s.client.ChainID,
		To:        target,
		Nonce:     nonce,
		GasFeeCap: s.Opts.GasFeeCap,
		GasTipCap: s.Opts.GasTipCap,
		Gas:       gasLimit,
		Value:     value,
		Data:      data,
	}))
}

// SendTransaction sends a transaction to the given Ethereum node.
func (s *Sender) SendTransaction(tx *types.Transaction) (string, error) {
	if s.unconfirmedTxs.Count() >= unconfirmedTxsCap {
		return "", fmt.Errorf("too many pending transactions")
	}

	txData, err := s.buildTxData(tx)
	if err != nil {
		return "", err
	}

	txID := uuid.New()
	txToConfirm := &TxToConfirm{
		ID:         txID,
		originalTx: txData,
		CurrentTx:  tx,
	}

	if err := s.send(txToConfirm); err != nil && !strings.Contains(err.Error(), "replacement transaction") {
		log.Error("Failed to send transaction",
			"tx_id", txID,
			"nonce", txToConfirm.CurrentTx.Nonce(),
			"hash", tx.Hash(),
			"err", err,
		)
		return "", err
	}

	// Add the transaction to the unconfirmed transactions
	s.unconfirmedTxs.Set(txID, txToConfirm)
	s.txToConfirmCh.Set(txID, make(chan *TxToConfirm, 1))

	return txID, nil
}

// send is the internal method to send the given transaction.
func (s *Sender) send(tx *TxToConfirm) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	originalTx := tx.originalTx

	for i := 0; i < nonceIncorrectRetrys; i++ {
		// Retry when nonce is incorrect
		rawTx, err := s.Opts.Signer(s.Opts.From, types.NewTx(originalTx))
		if err != nil {
			return err
		}
		tx.CurrentTx = rawTx
		err = s.client.SendTransaction(s.ctx, rawTx)
		tx.Err = err
		// Check if the error is nonce too low
		if err != nil {
			if strings.Contains(err.Error(), "nonce too low") {
				s.AdjustNonce(originalTx)
				log.Warn("Nonce is incorrect, retry sending the transaction with new nonce",
					"tx_id", tx.ID,
					"nonce", tx.CurrentTx.Nonce(),
					"hash", rawTx.Hash(),
					"err", err,
				)
				continue
			}
			if strings.Contains(err.Error(), "replacement transaction underpriced") {
				s.adjustGas(originalTx)
				log.Warn("Replacement transaction underpriced",
					"tx_id", tx.ID,
					"nonce", tx.CurrentTx.Nonce(),
					"hash", rawTx.Hash(),
					"err", err,
				)
				continue
			}
			log.Error("Failed to send transaction",
				"tx_id", tx.ID,
				"nonce", tx.CurrentTx.Nonce(),
				"hash", rawTx.Hash(),
				"err", err,
			)
			return err
		}
		break
	}
	s.Opts.Nonce = new(big.Int).Add(s.Opts.Nonce, common.Big1)
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
		if err := s.send(unconfirmedTx); err != nil {
			log.Warn(
				"Failed to resend the transaction",
				"tx_id", id,
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
				log.Warn("Failed to fetch transaction",
					"tx_id", pendingTx.ID,
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
			pendingTx.Receipt = receipt
			if receipt.Status != types.ReceiptStatusSuccessful {
				pendingTx.Err = fmt.Errorf("transaction reverted, hash: %s", receipt.TxHash)
				s.releaseUnconfirmedTx(id)
				continue
			}
		}
		pendingTx.confirmations = s.head.Number.Uint64() - pendingTx.Receipt.BlockNumber.Uint64()
		if pendingTx.confirmations >= s.ConfirmationDepth {
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
