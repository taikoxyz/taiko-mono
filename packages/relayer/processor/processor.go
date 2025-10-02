package processor

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc1155vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc20vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc721vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/quotamanager"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/utils"
)

// ethClient is a slimmed down interface of a go-ethereum ethclient.Client
// we can use for mocking and testing
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
	EstimateGas(ctx context.Context, msg ethereum.CallMsg) (uint64, error)
	BalanceAt(ctx context.Context, account common.Address, blockNumber *big.Int) (*big.Int, error)
	CodeAt(ctx context.Context, account common.Address, blockNumber *big.Int) ([]byte, error)
}

// hop is a struct which needs to be created based on the config parameters
// for a hop. Each hop is an intermediary hop - if we are just processing
// srcChain to destChain, we should have no hops.
type hop struct {
	chainID              *big.Int
	signalServiceAddress common.Address
	signalService        relayer.SignalService
	taikoAddress         common.Address
	ethClient            ethClient
	caller               relayer.Caller
}

// Processor is the main struct which handles message processing and queue
// instantiation
type Processor struct {
	cancel context.CancelFunc

	eventRepo relayer.EventRepository

	queue queue.Queue

	hops []hop

	srcEthClient  ethClient
	destEthClient ethClient
	srcCaller     relayer.Caller

	ecdsaKey *ecdsa.PrivateKey

	srcSignalService relayer.SignalService

	destBridge       relayer.Bridge
	destERC20Vault   relayer.TokenVault
	destERC1155Vault relayer.TokenVault
	destERC721Vault  relayer.TokenVault
	destQuotaManager relayer.QuotaManager

	prover *proof.Prover

	relayerAddr             common.Address
	srcSignalServiceAddress common.Address

	confirmations uint64

	profitableOnly            bool
	headerSyncIntervalSeconds int64

	confTimeoutInSeconds int64

	backOffRetryInterval time.Duration
	backOffMaxRetries    uint64
	ethClientTimeout     time.Duration

	msgCh chan queue.Message

	wg sync.WaitGroup

	srcChainId  *big.Int
	destChainId *big.Int

	taikoL2 *taikol2.TaikoL2

	targetTxHash *common.Hash // optional, set to target processing a specific txHash only

	cfg *Config

	txmgr txmgr.TxManager

	maxMessageRetries uint64

	processingTxHashes map[common.Hash]bool
	processingTxHashMu sync.Mutex

	minFeeToProcess uint64
}

// InitFromCli creates a new processor from a cli context
func (p *Processor) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, p, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, p *Processor, cfg *Config) error {
	p.cfg = cfg

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

	hops := []hop{}

	// iteraate over all the hop configs and create a hop struct
	// which can be used to generate hop proofs
	for _, hopConfig := range cfg.hopConfigs {
		var hopEthClient *ethclient.Client

		var hopChainID *big.Int

		var hopRpcClient *rpc.Client

		var hopSignalService *signalservice.SignalService

		hopEthClient, err = ethclient.Dial(hopConfig.rpcURL)
		if err != nil {
			return err
		}

		hopChainID, err = hopEthClient.ChainID(context.Background())
		if err != nil {
			return err
		}

		hopSignalService, err = signalservice.NewSignalService(
			hopConfig.signalServiceAddress,
			hopEthClient,
		)
		if err != nil {
			return err
		}

		hopRpcClient, err = rpc.Dial(hopConfig.rpcURL)
		if err != nil {
			return err
		}

		// only support one hop rn, add in array configs
		// to support more.
		hops = append(hops, hop{
			caller:               hopRpcClient,
			signalServiceAddress: hopConfig.signalServiceAddress,
			taikoAddress:         hopConfig.taikoAddress,
			chainID:              hopChainID,
			signalService:        hopSignalService,
			ethClient:            hopEthClient,
		})
	}

	srcSignalService, err := signalservice.NewSignalService(
		cfg.SrcSignalServiceAddress,
		srcEthClient,
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

	var destQuotaManager *quotamanager.QuotaManager

	if cfg.DestQuotaManagerAddress.Hex() != relayer.ZeroAddress.Hex() {
		destQuotaManager, err = quotamanager.NewQuotaManager(
			cfg.DestQuotaManagerAddress,
			destEthClient,
		)
		if err != nil {
			return err
		}

		p.destQuotaManager = destQuotaManager
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

	prover, err := proof.New(srcEthClient, p.cfg.CacheOption)
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

	var q queue.Queue
	if cfg.TargetTxHash == nil {
		q, err = cfg.OpenQueueFunc()
		if err != nil {
			return err
		}
	}

	if p.txmgr, err = txmgr.NewSimpleTxManager(
		"processor",
		log.Root(),
		new(txmgrMetrics.NoopTxMetrics),
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	p.hops = hops
	p.prover = prover
	p.eventRepo = eventRepository

	p.srcEthClient = srcEthClient
	p.destEthClient = destEthClient

	p.srcSignalService = srcSignalService

	p.destBridge = destBridge
	p.destERC1155Vault = destERC1155Vault
	p.destERC20Vault = destERC20Vault
	p.destERC721Vault = destERC721Vault

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
	p.srcCaller = srcRpcClient

	p.backOffRetryInterval = time.Duration(cfg.BackoffRetryInterval) * time.Second
	p.backOffMaxRetries = cfg.BackOffMaxRetries
	p.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	p.targetTxHash = cfg.TargetTxHash

	p.maxMessageRetries = cfg.MaxMessageRetries

	p.processingTxHashes = make(map[common.Hash]bool, 0)

	p.minFeeToProcess = p.cfg.MinFeeToProcess

	slog.Info("minFeeToProcess", "minFeeToProcess", p.minFeeToProcess)

	return nil
}

func (p *Processor) Name() string {
	return "processor"
}

func (p *Processor) Close(ctx context.Context) {
	p.cancel()

	p.wg.Wait()

	// Close db connection.
	if err := p.eventRepo.Close(); err != nil {
		slog.Error("Failed to close db connection", "err", err)
	}
}

func (p *Processor) Start() error {
	ctx, cancel := context.WithCancel(context.Background())

	p.cancel = cancel

	// if a targetTxHash is set, we only want to process that specific one.
	if p.targetTxHash != nil {
		err := p.processSingle(ctx)
		if err != nil {
			slog.Error(err.Error())
		}

		os.Exit(0)
	}

	// otherwise, we can start the queue, and process messages from it
	// via eventloop.

	if err := p.queue.Start(ctx, p.queueName()); err != nil {
		slog.Error("error starting queue", "error", err)

		return err
	}

	go func() {
		if err := backoff.Retry(func() error {
			slog.Info("attempting backoff queue subscription")
			if err := p.queue.Subscribe(ctx, p.msgCh, &p.wg); err != nil {
				slog.Error("processor queue subscription error", "err", err.Error())
				return err
			}

			return nil
		}, backoff.WithContext(backoff.NewConstantBackOff(1*time.Second), ctx)); err != nil {
			slog.Error("rabbitmq subscribe backoff retry error", "err", err.Error())
		}
	}()

	go p.eventLoop(ctx)

	go func() {
		if err := backoff.Retry(func() error {
			return utils.ScanBlocks(ctx, p.srcEthClient, &p.wg)
		}, backoff.NewConstantBackOff(5*time.Second)); err != nil {
			slog.Error("scan blocks backoff retry", "error", err)
		}
	}()

	return nil
}

func (p *Processor) queueName() string {
	return fmt.Sprintf("%v-%v-%v-queue", p.srcChainId.String(), p.destChainId.String(), relayer.EventNameMessageSent)
}

// eventLoop is the main event loop of a Processor which should read
// messages from a queue and then process them.
func (p *Processor) eventLoop(ctx context.Context) {
	p.wg.Add(1)
	defer p.wg.Done()

	for {
		select {
		case <-ctx.Done():
			return
		case msg := <-p.msgCh:
			go func(m queue.Message) {
				shouldRequeue, timesRetried, err := p.processMessage(ctx, m)

				if err != nil {
					switch {
					case errors.Is(err, errUnprocessable):
						if err := p.queue.Ack(ctx, m); err != nil {
							slog.Error("Err acking message", "err", err.Error())
						}
					case errors.Is(err, relayer.ErrUnprofitable):
						slog.Info("publishing to unprofitable queue")

						headers := make(map[string]interface{}, 0)

						headers["retries"] = int64(timesRetried + 1)

						if err := p.queue.Publish(
							ctx,
							fmt.Sprintf("%v-unprofitable", p.queueName()),
							m.Body,
							headers,
							p.cfg.UnprofitableMessageQueueExpiration,
						); err != nil {
							slog.Error("error publishing to unprofitable queue", "error", err)
						}

						// after publishing successfully, we can acknowledge this message to remove it
						// from our main queue.
						if err := p.queue.Ack(ctx, m); err != nil {
							slog.Error("Err acking message", "err", err.Error())
						}
					case errors.Is(err, context.Canceled) ||
						strings.Contains(err.Error(), "timeout") ||
						strings.Contains(err.Error(), "i/o") ||
						strings.Contains(err.Error(), "connect") ||
						strings.Contains(err.Error(), "failed to get tx into the mempool"):
						// we want to do nothing, just log, and the message will be re-picked up
						// by another consumer. no need to nack or ack.
						slog.Error("process message failed", "err", err.Error())
					default:
						slog.Error("process message failed", "err", err.Error())

						// we want to negatively acknowledge the message and requeue it if we
						// encountered an error, but the message is processable.
						if err := p.queue.Nack(ctx, m, shouldRequeue); err != nil {
							slog.Error("Err nacking message", "err", err.Error())
						}
					}

					return
				}

				if shouldRequeue {
					// we want to negatively acknowledge the message
					if err := p.queue.Nack(ctx, m, true); err != nil {
						slog.Error("Err nacking message", "err", err.Error())
					}

					marshalledMsg, err := json.Marshal(msg)
					if err != nil {
						slog.Error("err marshaling queue message", "err", err.Error())
					} else {
						if err := p.queue.Publish(ctx, p.queueName(), marshalledMsg, nil, nil); err != nil {
							slog.Error("err publishing to queue", "err", err.Error())
						}
					}
				} else {
					// otherwise if no error, we can acknowledge it successfully.
					if err := p.queue.Ack(ctx, m); err != nil {
						slog.Error("Err acking message", "err", err.Error())
					}
				}
			}(msg)
		}
	}
}
