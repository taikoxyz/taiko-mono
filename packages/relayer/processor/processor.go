package processor

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc1155vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc20vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc721vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/quotamanager"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/rpcclient"
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
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
	ChainID(ctx context.Context) (*big.Int, error)
	EstimateGas(ctx context.Context, msg ethereum.CallMsg) (uint64, error)
	BalanceAt(ctx context.Context, account common.Address, blockNumber *big.Int) (*big.Int, error)
	CodeAt(ctx context.Context, account common.Address, blockNumber *big.Int) ([]byte, error)
}

// Processor is the main struct which handles message processing and queue
// instantiation
type Processor struct {
	cancel context.CancelFunc

	eventRepo relayer.EventRepository

	queue queue.Queue

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

	// minTipCap is the minimum tip cap (in wei) the tx manager enforces when
	// sending transactions. The profitability estimate floors the suggested tip
	// at this value so it reflects what the tx manager actually pays.
	minTipCap *big.Int
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

	srcRpcClient, err := rpcclient.Dial(ctx, cfg.SrcRPCUrl, cfg.ETHClientRequestTimeout)
	if err != nil {
		return err
	}

	srcEthClient := ethclient.NewClient(srcRpcClient)

	destEthClient, err := rpcclient.DialEthClient(ctx, cfg.DestRPCUrl, cfg.ETHClientRequestTimeout)
	if err != nil {
		return err
	}

	if cfg.SrcSignalServiceAddress == relayer.ZeroAddress {
		return errors.New("srcSignalServiceAddress not provided")
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

	var q queue.Queue
	if cfg.TargetTxHash == nil {
		q, err = cfg.OpenQueueFunc()
		if err != nil {
			return err
		}
	}

	// A negative timeout is not a smaller one: it makes every context deadline already past, so
	// every send fails before it is attempted. Nothing downstream rejects it, and being non-zero it
	// would silently take the place of the default supplied below.
	if cfg.TxmgrConfigs.TxSendTimeout < 0 {
		return fmt.Errorf(
			"invalid txmgr.send-timeout %s: a negative timeout expires every send immediately",
			cfg.TxmgrConfigs.TxSendTimeout,
		)
	}

	// Settled before anything is dialled: NewConfig below copies TxSendTimeout across unchanged,
	// so this is the last point at which it can still be supplied.
	if timeout, defaulted := privateRPCSendTimeout(
		len(cfg.DestPrivateRPCUrls),
		cfg.TxmgrConfigs.TxSendTimeout,
	); defaulted {
		cfg.TxmgrConfigs.TxSendTimeout = timeout

		slog.Info("Bounding sends for private endpoints",
			"txSendTimeout", timeout,
			"reason", "a relay can accept a transaction and never include it",
		)
	}

	txmgrConfig, err := txmgr.NewConfig(*cfg.TxmgrConfigs, log.Root())
	if err != nil {
		return err
	}

	// Only the broadcast goes private. Reads stay on cfg.DestRPCUrl, which keeps one nonce source
	// behind the single transaction manager below: separate managers over the same key would each
	// resolve the nonce against their own endpoint, and a private endpoint does not gossip, so two
	// concurrent claims could be signed with the same nonce.
	privateSenders, err := dialPrivateSenders(ctx, cfg.DestPrivateRPCUrls)
	if err != nil {
		// NewConfig already dialled the public endpoint; nothing owns it until the backend below
		// wraps it, so it has to be closed here rather than left open for the process's life.
		txmgrConfig.Backend.Close()

		return err
	}

	sendingBackend := installPrivateSending(
		txmgrConfig,
		privateSenders,
		privateRPCHosts(cfg.DestPrivateRPCUrls),
		&cfg.PrivateRPCRetryInterval,
	)

	if p.txmgr, err = txmgr.NewSimpleTxManagerFromConfig(
		"processor",
		log.Root(),
		new(txmgrMetrics.NoopTxMetrics),
		txmgrConfig,
	); err != nil {
		sendingBackend.Close()

		return err
	}

	slog.Info("Processor tx manager initialized",
		"privateEndpoints", sendingBackend.NumPrivateEndpoints(),
	)

	// Mirror the tx manager's minimum tip cap so the profitability estimate can
	// floor the suggested tip at the same value the tx manager will pay.
	minTipCap, err := eth.GweiToWei(cfg.TxmgrConfigs.MinTipCapGwei)
	if err != nil {
		return err
	}

	p.minTipCap = minTipCap

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

// dialPrivateSenders opens a client for each private endpoint, preserving the configured failover
// order. Nothing owns these until the sending backend does, so a URL that fails part-way through
// closes the clients already opened rather than leaking them for the life of the process.
//
// For http and https the client is built without contacting the endpoint, so a relay that is down
// does not fail this; config parsing rejects every other scheme for that reason.
// privateRPCHosts returns the host names of the configured endpoints, for keeping them out of the
// text of any error this processor logs. Entries that will not parse contribute nothing: they are
// rejected before this point, and a blank host would match everywhere.
func privateRPCHosts(urls []string) []string {
	hosts := make([]string, 0, len(urls))

	for _, endpoint := range urls {
		parsed, err := url.Parse(endpoint)
		if err != nil || parsed.Hostname() == "" {
			continue
		}

		hosts = append(hosts, parsed.Hostname())
	}

	return hosts
}

func dialPrivateSenders(ctx context.Context, urls []string) ([]utils.TxSender, error) {
	clients := make([]*ethclient.Client, 0, len(urls))

	for _, endpoint := range urls {
		client, err := ethclient.DialContext(ctx, endpoint)
		if err != nil {
			for _, opened := range clients {
				opened.Close()
			}

			// The dial error quotes the endpoint it was given, API key and all, and this one is
			// returned to a caller that logs it and exits.
			return nil, utils.Redact(err, privateRPCHosts(urls))
		}

		clients = append(clients, client)
	}

	senders := make([]utils.TxSender, 0, len(clients))
	for _, client := range clients {
		senders = append(senders, client)
	}

	return senders, nil
}

// installPrivateSending puts a SendingBackend between the transaction manager and the chain, so
// that broadcasts go to the private endpoints while every read still goes to the endpoint the
// transaction manager was configured with. It returns the backend so the caller can close it.
//
// This is a named function rather than two lines inline because the assignment is the whole
// feature: without it every claim is signed and broadcast exactly as before, through the public
// mempool, and nothing else observes the difference. Kept inline it had no test that failed when
// it was removed.
func installPrivateSending(
	txmgrConfig *txmgr.Config,
	senders []utils.TxSender,
	hosts []string,
	retryInterval *time.Duration,
) *utils.SendingBackend {
	backend := utils.NewSendingBackend(txmgrConfig.Backend, senders, hosts, retryInterval)

	txmgrConfig.Backend = backend

	return backend
}

func (p *Processor) Name() string {
	return "processor"
}

// WaitForInterrupt returns whether processor should keep running and wait for
// shutdown signals after Start() returns.
func (p *Processor) WaitForInterrupt() bool {
	return p.targetTxHash == nil
}

func (p *Processor) Close(ctx context.Context) {
	p.cancel()

	p.wg.Wait()

	// Closing the tx manager closes the backend under it, which is what holds the connections to
	// the private endpoints. Without this they are left open for the life of the process.
	if p.txmgr != nil && !p.txmgr.IsClosed() {
		p.txmgr.Close()
	}

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
		return p.processSingle(ctx)
	}

	// otherwise, we can start the queue, and process messages from it
	// via eventloop.

	if err := p.queue.Start(ctx, p.queueName()); err != nil {
		slog.Error("error starting queue", "error", err)

		return err
	}

	go func() {
		bo := backoff.WithContext(
			backoff.WithMaxRetries(
				backoff.NewConstantBackOff(p.backOffRetryInterval),
				p.backOffMaxRetries,
			),
			ctx,
		)

		if err := backoff.Retry(func() error {
			slog.Info("attempting backoff queue subscription")
			if err := p.queue.Subscribe(ctx, p.msgCh, &p.wg); err != nil {
				slog.Error("processor queue subscription error", "err", err.Error())
				return err
			}

			return nil
		}, bo); err != nil {
			slog.Error("rabbitmq subscribe backoff retry error, exiting so container restarts", "err", err.Error())
			os.Exit(1)
		}
	}()

	go p.eventLoop(ctx)

	go func() {
		bo := backoff.WithContext(backoff.NewConstantBackOff(5*time.Second), ctx)
		if err := backoff.Retry(func() error {
			return utils.ScanBlocks(ctx, p.srcEthClient, &p.wg)
		}, bo); err != nil {
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
				defer func() {
					if r := recover(); r != nil {
						slog.Error("panic processing message", "panic", r)

						if err := p.queue.Nack(ctx, m, false); err != nil {
							slog.Error("Err nacking panicked message", "err", err.Error())
						}
					}
				}()

				shouldRequeue, timesRetried, err := p.processMessage(ctx, m)
				p.handleProcessMessageResult(ctx, m, shouldRequeue, timesRetried, err)
			}(msg)
		}
	}
}

func (p *Processor) handleProcessMessageResult(
	ctx context.Context,
	m queue.Message,
	shouldRequeue bool,
	timesRetried uint64,
	err error,
) {
	if err != nil {
		switch {
		case errors.Is(err, errUnprocessable):
			if err := p.queue.Ack(ctx, m); err != nil {
				slog.Error("Err acking message", "err", err.Error())
			}
		case errors.Is(err, relayer.ErrUnprofitable):
			p.handleUnprofitableMessage(ctx, m, timesRetried)
		case isTransientProcessMessageError(err):
			slog.Error("process message failed", "err", err.Error())

			p.handleTransientProcessMessageError(ctx, m)
		default:
			slog.Error("process message failed", "err", err.Error())

			if err := p.queue.Nack(ctx, m, shouldRequeue); err != nil {
				slog.Error("Err nacking message", "err", err.Error())
			}
		}

		return
	}

	if shouldRequeue {
		if err := p.queue.Nack(ctx, m, true); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}
	} else if err := p.queue.Ack(ctx, m); err != nil {
		slog.Error("Err acking message", "err", err.Error())
	}
}

func (p *Processor) handleUnprofitableMessage(ctx context.Context, m queue.Message, timesRetried uint64) {
	slog.Info("publishing to unprofitable queue")

	headers := make(map[string]interface{}, 0)
	nextRetries := timesRetried + 1
	headers["retries"] = int64(nextRetries)

	msgBody := &queue.QueueMessageSentBody{}
	if err := json.Unmarshal(m.Body, msgBody); err != nil {
		slog.Error("error decoding unprofitable message", "error", err)

		if err := p.queue.Nack(ctx, m, false); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}

		return
	}

	msgBody.TimesRetried = nextRetries

	body, err := json.Marshal(msgBody)
	if err != nil {
		slog.Error("error encoding unprofitable message", "error", err)

		if err := p.queue.Nack(ctx, m, false); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}

		return
	}

	if err := p.queue.Publish(
		ctx,
		fmt.Sprintf("%v-unprofitable", p.queueName()),
		body,
		headers,
		p.cfg.UnprofitableMessageQueueExpiration,
	); err != nil {
		slog.Error("error publishing to unprofitable queue", "error", err)

		if err := p.queue.Nack(ctx, m, true); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}

		return
	}

	if err := p.queue.Ack(ctx, m); err != nil {
		slog.Error("Err acking message", "err", err.Error())
	}
}

// DefaultTransientErrorQueueExpiration is how long a transiently failed message waits before it is
// offered again, when the configuration did not say.
const DefaultTransientErrorQueueExpiration = "30000"

// handleTransientProcessMessageError parks a message that failed for a transient reason on a queue
// that holds it for TRANSIENT_ERROR_QUEUE_EXPIRATION and then routes it back for another attempt.
//
// Nacking it back onto the main queue instead would return it to the head immediately. The consumer
// prefetches one message by default and acknowledges only after processing, so exactly one message
// is in flight per replica: a claim that keeps failing — a MessageSent whose source transaction was
// reorged out returns a bare deadline every time — would be handed straight back, forever, and the
// replica would relay nothing else. Nothing counts those attempts either, so the queue depth is the
// only sign of it.
//
// The attempt is not capped. A transient failure says nothing about whether the claim is good, and
// this relayer must not skip one it could land, so the message keeps coming back; the wait is what
// keeps it from monopolising the replica, and TimesRequeued is what makes it visible.
//
// The wait bounds how often such a claim is attempted, not what each attempt costs. The delivery is
// still held for the whole failing attempt before it is parked, which for a source transaction that
// never confirms is CONFIRMATIONS_TIMEOUT — longer than the expiration. So this is ordering under a
// backlog rather than a claim that costs nothing, and it is why the halt is gone but a fresh claim
// on a quiet queue can still wait minutes behind a poisoned one.
func (p *Processor) handleTransientProcessMessageError(ctx context.Context, m queue.Message) {
	msgBody := &queue.QueueMessageSentBody{}
	if err := json.Unmarshal(m.Body, msgBody); err != nil {
		slog.Error("error decoding transiently failed message", "error", err)

		// Undecodable, so it cannot be republished with its count. Requeuing is still better than
		// dead-lettering a claim that may be perfectly good.
		if err := p.queue.Nack(ctx, m, true); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}

		return
	}

	msgBody.TimesRequeued++

	body, err := json.Marshal(msgBody)
	if err != nil {
		slog.Error("error encoding transiently failed message", "error", err)

		if err := p.queue.Nack(ctx, m, true); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}

		return
	}

	headers := map[string]interface{}{"requeues": int64(msgBody.TimesRequeued)}

	// A nil expiration would park the message with nothing to bring it back, which is the one
	// outcome this path must not produce. The configuration always sets it; this covers a
	// Processor built without going through it.
	expiration := p.cfg.TransientErrorQueueExpiration
	if expiration == nil {
		fallback := DefaultTransientErrorQueueExpiration
		expiration = &fallback
	}

	if err := p.queue.Publish(
		ctx,
		fmt.Sprintf("%v-transient", p.queueName()),
		body,
		headers,
		expiration,
	); err != nil {
		slog.Error("error publishing to transient queue", "error", err)

		// The wait is an optimisation; not being able to take it is no reason to drop the claim.
		if err := p.queue.Nack(ctx, m, true); err != nil {
			slog.Error("Err nacking message", "err", err.Error())
		}

		return
	}

	relayer.MessageSentEventsRequeuedTransient.Inc()

	slog.Info("message parked after a transient failure",
		"timesRequeued", msgBody.TimesRequeued,
		"expiration", *expiration,
	)

	// Acked only once the copy is safely on the transient queue, so a crash in between leaves the
	// original unacknowledged and the broker redelivers it.
	if err := p.queue.Ack(ctx, m); err != nil {
		slog.Error("Err acking message", "err", err.Error())
	}
}

func isTransientProcessMessageError(err error) bool {
	return errors.Is(err, context.Canceled) ||
		// A send that ran out of time is worth retrying. Its text matches none of the strings
		// below, and without this the queue would drop the claim.
		errors.Is(err, context.DeadlineExceeded) ||
		// The claim lost a race for its nonce and has to be signed again, which is the one thing
		// this error means. The transaction manager gives up on a nonce after
		// SafeAbortNonceTooLowCount refusals and returns "aborted tx send due to critical error:
		// nonce too low", which matches none of the strings below — so the message was
		// dead-lettered, and the dead-letter queue has no consumer. A claim nobody had processed
		// was parked there for good. The sentinel is %w-wrapped, so this matches it exactly.
		errors.Is(err, core.ErrNonceTooLow) ||
		strings.Contains(err.Error(), "timeout") ||
		strings.Contains(err.Error(), "i/o") ||
		strings.Contains(err.Error(), "connect") ||
		strings.Contains(err.Error(), "failed to get tx into the mempool")
}
