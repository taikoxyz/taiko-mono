package watchdog

import (
	"context"
	"crypto/ecdsa"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"
	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/utils"
)

type DB interface {
	DB() (*sql.DB, error)
	GormDB() *gorm.DB
}

type ethClient interface {
	PendingNonceAt(ctx context.Context, account common.Address) (uint64, error)
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
	BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error)
	BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error)
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
	ChainID(ctx context.Context) (*big.Int, error)
}

type Watchdog struct {
	cancel context.CancelFunc

	eventRepo       relayer.EventRepository
	suspendedTxRepo relayer.SuspendedTransactionRepository

	queue queue.Queue

	srcEthClient  ethClient
	destEthClient ethClient

	ecdsaKey *ecdsa.PrivateKey

	srcBridge  relayer.Bridge
	destBridge relayer.Bridge

	mu *sync.Mutex

	destNonce    uint64
	watchdogAddr common.Address

	confirmations uint64

	confTimeoutInSeconds int64

	backOffRetryInterval time.Duration
	backOffMaxRetries    uint64
	ethClientTimeout     time.Duration

	msgCh chan queue.Message

	wg *sync.WaitGroup

	srcChainId  *big.Int
	destChainId *big.Int
}

func (w *Watchdog) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, w, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, w *Watchdog, cfg *Config) error {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return err
	}

	suspendedTxRepo, err := repo.NewSuspendedTransactionRepository(db)
	if err != nil {
		return err
	}

	srcEthClient, err := ethclient.Dial(cfg.SrcRPCUrl)
	if err != nil {
		return err
	}

	destEthClient, err := ethclient.Dial(cfg.DestRPCUrl)
	if err != nil {
		return err
	}

	srcBridge, err := bridge.NewBridge(cfg.SrcBridgeAddress, srcEthClient)
	if err != nil {
		return err
	}

	destBridge, err := bridge.NewBridge(cfg.DestBridgeAddress, destEthClient)
	if err != nil {
		return err
	}

	srcChainID, err := srcEthClient.ChainID(context.Background())
	if err != nil {
		return err
	}

	destChainID, err := destEthClient.ChainID(context.Background())
	if err != nil {
		return err
	}

	publicKey := cfg.WatchdogPrivateKey.Public()

	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return errors.New("unable to convert public key")
	}

	watchdogAddr := crypto.PubkeyToAddress(*publicKeyECDSA)

	q, err := cfg.OpenQueueFunc()
	if err != nil {
		return err
	}

	w.eventRepo = eventRepository
	w.suspendedTxRepo = suspendedTxRepo

	w.srcEthClient = srcEthClient
	w.destEthClient = destEthClient

	w.destBridge = destBridge
	w.srcBridge = srcBridge

	w.ecdsaKey = cfg.WatchdogPrivateKey
	w.watchdogAddr = watchdogAddr

	w.queue = q

	w.srcChainId = srcChainID
	w.destChainId = destChainID

	w.confTimeoutInSeconds = int64(cfg.ConfirmationsTimeout)
	w.confirmations = cfg.Confirmations

	w.msgCh = make(chan queue.Message)
	w.wg = &sync.WaitGroup{}
	w.mu = &sync.Mutex{}

	w.backOffRetryInterval = time.Duration(cfg.BackoffRetryInterval) * time.Second
	w.backOffMaxRetries = cfg.BackOffMaxRetrys
	w.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	return nil
}

func (w *Watchdog) Name() string {
	return "watchdog"
}

func (w *Watchdog) Close(ctx context.Context) {
	w.cancel()

	w.wg.Wait()
}

func (w *Watchdog) Start() error {
	ctx, cancel := context.WithCancel(context.Background())

	w.cancel = cancel

	if err := w.queue.Start(ctx, w.queueName()); err != nil {
		slog.Error("error starting queue", "error", err)

		return err
	}

	go func() {
		if err := backoff.Retry(func() error {
			slog.Info("attempting backoff queue subscription")
			if err := w.queue.Subscribe(ctx, w.msgCh, w.wg); err != nil {
				slog.Error("processor queue subscription error", "err", err.Error())
				return err
			}

			return nil
		}, backoff.NewConstantBackOff(1*time.Second)); err != nil {
			slog.Error("rabbitmq subscribe backoff retry error", "err", err.Error())
		}
	}()

	w.wg.Add(1)

	go w.eventLoop(ctx)

	return nil
}

func (w *Watchdog) queueName() string {
	return fmt.Sprintf("%v-%v-%v-queue", w.srcChainId.String(), w.destChainId.String(), relayer.EventNameMessageReceived)
}

func (w *Watchdog) eventLoop(ctx context.Context) {
	defer func() {
		w.wg.Done()
	}()

	for {
		select {
		case <-ctx.Done():
			return
		case msg := <-w.msgCh:
			go func(msg queue.Message) {
				err := w.checkMessage(ctx, msg)

				if err != nil {
					slog.Error("err checking message", "err", err.Error())

					if err := w.queue.Nack(ctx, msg, true); err != nil {
						slog.Error("Err nacking message", "err", err.Error())
					}
				} else {
					if err := w.queue.Ack(ctx, msg); err != nil {
						slog.Error("Err acking message", "err", err.Error())
					}
				}
			}(msg)
		}
	}
}

// checkMessage checks a MessageReceived event message and makes sure
// that the message was actually sent on the source chain. If it wasn't,
// we send a suspend transaction.
func (w *Watchdog) checkMessage(ctx context.Context, msg queue.Message) error {
	msgBody := &queue.QueueMessageReceivedBody{}
	if err := json.Unmarshal(msg.Body, msgBody); err != nil {
		return errors.Wrap(err, "json.Unmarshal")
	}

	// check if the source chain sent this message
	sent, err := w.srcBridge.IsMessageSent(nil, msgBody.Event.Message)
	if err != nil {
		return errors.Wrap(err, "w.srcBridge.IsMessageSent")
	}

	// if so, do nothing, acknowledge message
	if sent {
		slog.Info("source bridge did send this message. returning early",
			"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
			"sent", sent,
		)

		return nil
	}

	// if not, we need to suspend

	var tx *types.Transaction

	sendTx := func() error {
		if ctx.Err() != nil {
			return nil
		}

		tx, err = w.sendSuspendMessageTx(ctx, msgBody.Event)
		if err != nil {
			return err
		}

		return nil
	}

	if err := backoff.Retry(sendTx, backoff.WithMaxRetries(
		backoff.NewConstantBackOff(w.backOffRetryInterval),
		w.backOffMaxRetries),
	); err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(ctx, 4*time.Minute)

	defer cancel()

	_, err = relayer.WaitReceipt(ctx, w.destEthClient, tx.Hash())
	if err != nil {
		return errors.Wrap(err, "relayer.WaitReceipt")
	}

	slog.Info("Mined tx", "txHash", hex.EncodeToString(tx.Hash().Bytes()))

	relayer.TransactionsSuspended.Inc()

	if _, err := w.suspendedTxRepo.Save(ctx,
		relayer.SuspendTransactionOpts{
			MessageID:    int(msgBody.Event.Message.Id.Int64()),
			SrcChainID:   int(msgBody.Event.Message.SrcChainId),
			DestChainID:  int(msgBody.Event.Message.DestChainId),
			MessageOwner: msgBody.Event.Message.From.Hex(),
			Suspended:    true,
			MsgHash:      common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
		}); err != nil {
		return errors.Wrap(err, "w.suspendedTxRepo.Save")
	}

	return nil
}

func (w *Watchdog) setLatestNonce(nonce uint64) {
	w.destNonce = nonce
}

func (w *Watchdog) getLatestNonce(ctx context.Context, auth *bind.TransactOpts) error {
	pendingNonce, err := w.destEthClient.PendingNonceAt(ctx, w.watchdogAddr)
	if err != nil {
		return err
	}

	if pendingNonce > w.destNonce {
		w.setLatestNonce(pendingNonce)
	}

	auth.Nonce = big.NewInt(int64(w.destNonce))

	return nil
}

func (w *Watchdog) sendSuspendMessageTx(
	ctx context.Context,
	event *bridge.BridgeMessageReceived,
) (*types.Transaction, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(w.ecdsaKey, new(big.Int).SetUint64(event.Message.DestChainId))
	if err != nil {
		return nil, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.Context = ctx

	w.mu.Lock()
	defer w.mu.Unlock()

	err = w.getLatestNonce(ctx, auth)
	if err != nil {
		return nil, errors.New("p.getLatestNonce")
	}

	gas, err := utils.EstimateGas(
		ctx,
		w.ecdsaKey,
		event.MsgHash,
		new(big.Int).SetUint64(event.Message.DestChainId),
		func() (*types.Transaction, error) {
			return w.destBridge.SuspendMessages(auth, [][32]byte{event.MsgHash}, true)
		})

	if err != nil {
		return nil, errors.Wrap(err, "w.estimateGas")
	}

	auth.GasLimit = gas

	if err = utils.SetGasTipOrPrice(ctx, auth, w.destEthClient); err != nil {
		return nil, errors.Wrap(err, "w.setGasTipOrPrice")
	}

	// process the message on the destination bridge.
	tx, err := w.destBridge.SuspendMessages(auth, [][32]byte{event.MsgHash}, true)
	if err != nil {
		return nil, errors.Wrap(err, "w.destBridge.ProcessMessage")
	}

	w.setLatestNonce(tx.Nonce())

	return tx, nil
}
