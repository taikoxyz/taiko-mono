package processor

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
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"
	"github.com/taikoxyz/taiko-mono/packages/relayer/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/repo"
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
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
	ChainID(ctx context.Context) (*big.Int, error)
}

type Processor struct {
	cancel context.CancelFunc

	eventRepo relayer.EventRepository

	queue queue.Queue

	srcEthClient  ethClient
	destEthClient ethClient
	rpc           relayer.Caller

	ecdsaKey *ecdsa.PrivateKey

	destBridge       relayer.Bridge
	destHeaderSyncer relayer.HeaderSyncer
	destERC20Vault   relayer.TokenVault
	destERC1155Vault relayer.TokenVault
	destERC721Vault  relayer.TokenVault

	prover *proof.Prover

	mu *sync.Mutex

	destNonce               uint64
	relayerAddr             common.Address
	srcSignalServiceAddress common.Address
	confirmations           uint64

	profitableOnly            bool
	headerSyncIntervalSeconds int64

	confTimeoutInSeconds int64

	backOffRetryInterval time.Duration
	backOffMaxRetries    uint64
	ethClientTimeout     time.Duration

	msgCh chan queue.Message

	wg *sync.WaitGroup

	srcChainId  *big.Int
	destChainId *big.Int

	taikoL2 *taikol2.TaikoL2
}

func (p *Processor) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, p, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, p *Processor, cfg *Config) error {
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

	q, err := cfg.OpenQueueFunc()
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

	prover, err := proof.New(srcEthClient)
	if err != nil {
		return err
	}

	publicKey := cfg.ProcessorPrivateKey.Public()

	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return errors.New("unable to convert public key")
	}

	relayerAddr := crypto.PubkeyToAddress(*publicKeyECDSA)

	var taikoL2 *taikol2.TaikoL2
	if cfg.EnableTaikoL2 {
		taikoL2, err = taikol2.NewTaikoL2(cfg.DestTaikoAddress, destEthClient)
		if err != nil {
			return err
		}

		p.taikoL2 = taikoL2
	}

	p.prover = prover
	p.eventRepo = eventRepository

	p.srcEthClient = srcEthClient
	p.destEthClient = destEthClient

	p.destBridge = destBridge
	p.destERC1155Vault = destERC1155Vault
	p.destERC20Vault = destERC20Vault
	p.destERC721Vault = destERC721Vault
	p.destHeaderSyncer = destHeaderSyncer

	p.ecdsaKey = cfg.ProcessorPrivateKey
	p.relayerAddr = relayerAddr

	p.profitableOnly = cfg.ProfitableOnly

	p.queue = q

	p.srcChainId = srcChainID
	p.destChainId = destChainID

	p.headerSyncIntervalSeconds = int64(cfg.HeaderSyncInterval)
	p.confTimeoutInSeconds = int64(cfg.ConfirmationsTimeout)
	p.confirmations = cfg.Confirmations

	p.srcSignalServiceAddress = cfg.SrcSignalServiceAddress

	p.msgCh = make(chan queue.Message)
	p.wg = &sync.WaitGroup{}
	p.mu = &sync.Mutex{}
	p.rpc = srcRpcClient

	p.backOffRetryInterval = time.Duration(cfg.BackoffRetryInterval) * time.Second
	p.backOffMaxRetries = cfg.BackOffMaxRetrys
	p.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	return nil
}

func (p *Processor) Name() string {
	return "processor"
}

func (p *Processor) Close(ctx context.Context) {
	p.cancel()

	p.wg.Wait()
}

func (p *Processor) Start() error {
	ctx, cancel := context.WithCancel(context.Background())

	p.cancel = cancel

	if err := p.queue.Start(ctx, p.queueName()); err != nil {
		return err
	}

	go func() {
		if err := backoff.Retry(func() error {
			slog.Info("attempting backoff queue subscription")
			if err := p.queue.Subscribe(ctx, p.msgCh, p.wg); err != nil {
				slog.Error("processor queue subscription error", "err", err.Error())
				return err
			}

			return nil
		}, backoff.NewConstantBackOff(1*time.Second)); err != nil {
			slog.Error("rabbitmq subscribe backoff retry error", "err", err.Error())
		}
	}()

	p.wg.Add(1)
	go p.eventLoop(ctx)

	return nil
}

func (p *Processor) queueName() string {
	return fmt.Sprintf("%v-%v-queue", p.srcChainId.String(), p.destChainId.String())
}

func (p *Processor) eventLoop(ctx context.Context) {
	defer func() {
		p.wg.Done()
	}()

	for {
		select {
		case <-ctx.Done():
			return
		case msg := <-p.msgCh:
			go func(msg queue.Message) {
				err := p.processMessage(ctx, msg)

				if err != nil {
					slog.Error("err processing message", "err", err.Error())

					if errors.Is(err, errUnprocessable) {
						if err := p.queue.Ack(ctx, msg); err != nil {
							slog.Error("Err acking message", "err", err.Error())
						}
					} else {
						if err := p.queue.Nack(ctx, msg); err != nil {
							slog.Error("Err nacking message", "err", err.Error())
						}
					}
				} else {
					if err := p.queue.Ack(ctx, msg); err != nil {
						slog.Error("Err acking message", "err", err.Error())
					}
				}
			}(msg)
		}
	}
}
