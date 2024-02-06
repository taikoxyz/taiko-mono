package watchdog

import (
	"context"
	"crypto/ecdsa"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/urfave/cli/v2"
	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc1155vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc20vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc721vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/icrosschainsync"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
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

	eventRepo relayer.EventRepository

	queue queue.Queue

	srcEthClient  ethClient
	destEthClient ethClient
	srcCaller     relayer.Caller

	ecdsaKey *ecdsa.PrivateKey

	srcSignalService relayer.SignalService

	destBridge       relayer.Bridge
	destHeaderSyncer relayer.HeaderSyncer
	destERC20Vault   relayer.TokenVault
	destERC1155Vault relayer.TokenVault
	destERC721Vault  relayer.TokenVault

	mu *sync.Mutex

	destNonce               uint64
	watchdogAddr            common.Address
	srcSignalServiceAddress common.Address
	destHeaderSyncAddress   common.Address

	confirmations uint64

	confTimeoutInSeconds int64

	backOffRetryInterval time.Duration
	backOffMaxRetries    uint64
	ethClientTimeout     time.Duration

	msgCh chan queue.Message

	wg *sync.WaitGroup

	srcChainId  *big.Int
	destChainId *big.Int

	taikoL2 *taikol2.TaikoL2

	targetTxHash *common.Hash // optional, set to target processing a specific txHash only
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

	srcRpcClient, err := rpc.Dial(cfg.SrcRPCUrl)
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

	srcSignalService, err := signalservice.NewSignalService(
		cfg.SrcSignalServiceAddress,
		srcEthClient,
	)
	if err != nil {
		return err
	}

	destHeaderSyncer, err := icrosschainsync.NewICrossChainSync(
		cfg.DestTaikoAddress,
		destEthClient,
	)
	if err != nil {
		return err
	}

	destERC20Vault, err := erc20vault.NewERC20Vault(
		cfg.DestERC20VaultAddress,
		destEthClient,
	)
	if err != nil {
		return err
	}

	var destERC721Vault *erc721vault.ERC721Vault
	if cfg.DestERC721VaultAddress.Hex() != relayer.ZeroAddress.Hex() {
		destERC721Vault, err = erc721vault.NewERC721Vault(cfg.DestERC721VaultAddress, destEthClient)
		if err != nil {
			return err
		}
	}

	var destERC1155Vault *erc1155vault.ERC1155Vault
	if cfg.DestERC1155VaultAddress.Hex() != relayer.ZeroAddress.Hex() {
		destERC1155Vault, err = erc1155vault.NewERC1155Vault(
			cfg.DestERC1155VaultAddress,
			destEthClient,
		)
		if err != nil {
			return err
		}
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

	var taikoL2 *taikol2.TaikoL2
	if cfg.EnableTaikoL2 {
		taikoL2, err = taikol2.NewTaikoL2(cfg.DestTaikoAddress, destEthClient)
		if err != nil {
			return err
		}

		w.taikoL2 = taikoL2
	}

	var q queue.Queue

	w.eventRepo = eventRepository

	w.srcEthClient = srcEthClient
	w.destEthClient = destEthClient

	w.srcSignalService = srcSignalService

	w.destBridge = destBridge
	w.destERC1155Vault = destERC1155Vault
	w.destERC20Vault = destERC20Vault
	w.destERC721Vault = destERC721Vault
	w.destHeaderSyncer = destHeaderSyncer

	w.ecdsaKey = cfg.WatchdogPrivateKey
	w.watchdogAddr = watchdogAddr

	w.queue = q

	w.srcChainId = srcChainID
	w.destChainId = destChainID

	w.confTimeoutInSeconds = int64(cfg.ConfirmationsTimeout)
	w.confirmations = cfg.Confirmations

	w.srcSignalServiceAddress = cfg.SrcSignalServiceAddress
	w.destHeaderSyncAddress = cfg.DestTaikoAddress

	w.msgCh = make(chan queue.Message)
	w.wg = &sync.WaitGroup{}
	w.mu = &sync.Mutex{}
	w.srcCaller = srcRpcClient

	w.backOffRetryInterval = time.Duration(cfg.BackoffRetryInterval) * time.Second
	w.backOffMaxRetries = cfg.BackOffMaxRetrys
	w.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	w.targetTxHash = cfg.TargetTxHash

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

					if err := w.queue.Nack(ctx, msg); err != nil {
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

func (w *Watchdog) checkMessage(ctx context.Context, msg queue.Message) error {
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
