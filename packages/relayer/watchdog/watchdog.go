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
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"
	"gorm.io/gorm"

	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
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
	SubscribeNewHead(ctx context.Context, ch chan<- *types.Header) (ethereum.Subscription, error)
}

type Watchdog struct {
	cancel context.CancelFunc

	eventRepo relayer.EventRepository

	queue queue.Queue

	srcEthClient  ethClient
	destEthClient ethClient

	ecdsaKey *ecdsa.PrivateKey

	srcBridge  relayer.Bridge
	destBridge relayer.Bridge

	mu *sync.Mutex

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

	txmgr txmgr.TxManager

	cfg *Config
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

	if w.txmgr, err = txmgr.NewSimpleTxManager(
		"watchdog",
		log.Root(),
		new(txmgrMetrics.NoopTxMetrics),
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	w.eventRepo = eventRepository

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

	w.cfg = cfg

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
		}, backoff.WithContext(backoff.NewConstantBackOff(1*time.Second), ctx)); err != nil {
			slog.Error("rabbitmq subscribe backoff retry error", "err", err.Error())
		}
	}()

	w.wg.Add(1)

	go w.eventLoop(ctx)

	go func() {
		if err := backoff.Retry(func() error {
			return utils.ScanBlocks(ctx, w.srcEthClient, w.wg)
		}, backoff.NewConstantBackOff(5*time.Second)); err != nil {
			slog.Error("scan blocks backoff retry", "error", err)
		}
	}()

	return nil
}

func (w *Watchdog) queueName() string {
	return fmt.Sprintf("%v-%v-%v-queue", w.srcChainId.String(), w.destChainId.String(), relayer.EventNameMessageProcessed)
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
	msgBody := &queue.QueueMessageProcessedBody{}
	if err := json.Unmarshal(msg.Body, msgBody); err != nil {
		return errors.Wrap(err, "json.Unmarshal")
	}

	// check if the source chain sent this message
	sent, err := w.destBridge.IsMessageSent(nil, msgBody.Message)
	if err != nil {
		return errors.Wrap(err, "w.destBridge.IsMessageSent")
	}

	// if so, do nothing, acknowledge message
	if sent {
		slog.Info("dest bridge did send this message. returning early",
			"sent", sent,
		)

		return nil
	}

	pauseReceipt, err := w.pauseBridge(ctx)
	if err != nil {
		return err
	}

	slog.Info("Mined pause tx", "txHash", hex.EncodeToString(pauseReceipt.TxHash.Bytes()))

	relayer.BridgePaused.Inc()

	return nil
}

func (w *Watchdog) pauseBridge(ctx context.Context) (*types.Receipt, error) {
	data, err := encoding.BridgeABI.Pack("pause")
	if err != nil {
		return nil, errors.Wrap(err, "encoding.BridgeABI.Pack")
	}

	// pause the src bridge, which is the DESTINATION of the original message.
	candidate := txmgr.TxCandidate{
		TxData: data,
		Blobs:  nil,
		To:     &w.cfg.SrcBridgeAddress,
	}

	receipt, err := w.txmgr.Send(ctx, candidate)
	if err != nil {
		slog.Warn("Failed to send pause transaction", "error", err.Error())
		return nil, err
	}

	return receipt, nil
}
