package indexer

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
	"github.com/urfave/cli/v2"
	"golang.org/x/sync/errgroup"
	"gorm.io/gorm"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

var (
	eventName = relayer.EventNameMessageSent
)

type WatchMode string

var (
	Filter             WatchMode = "filter"
	Subscribe          WatchMode = "subscribe"
	FilterAndSubscribe WatchMode = "filter-and-subscribe"
	CrawlPastBlocks    WatchMode = "crawl-past-blocks"
	WatchModes                   = []WatchMode{Filter, Subscribe, FilterAndSubscribe, CrawlPastBlocks}
)

type SyncMode string

var (
	Sync   SyncMode = "sync"
	Resync SyncMode = "resync"
	Modes           = []SyncMode{Sync, Resync}
)

type ethClient interface {
	ChainID(ctx context.Context) (*big.Int, error)
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
	SubscribeNewHead(ctx context.Context, ch chan<- *types.Header) (ethereum.Subscription, error)
	BlockNumber(ctx context.Context) (uint64, error)
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
}

type DB interface {
	DB() (*sql.DB, error)
	GormDB() *gorm.DB
}

type Indexer struct {
	eventRepo    relayer.EventRepository
	blockRepo    relayer.BlockRepository
	srcEthClient ethClient

	processingBlockHeight uint64

	bridge     relayer.Bridge
	destBridge relayer.Bridge

	blockBatchSize      uint64
	numGoroutines       int
	subscriptionBackoff time.Duration

	taikol1 *taikol1.TaikoL1

	queue queue.Queue

	srcChainId  *big.Int
	destChainId *big.Int

	watchMode WatchMode
	syncMode  SyncMode

	ethClientTimeout time.Duration

	wg *sync.WaitGroup

	numLatestBlocksToIgnoreWhenCrawling uint64

	ctx context.Context
}

func (i *Indexer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, i, cfg)
}

func InitFromConfig(ctx context.Context, i *Indexer, cfg *Config) (err error) {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return err
	}

	blockRepository, err := repo.NewBlockRepository(db)
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

	srcBridge, err := bridge.NewBridge(cfg.SrcBridgeAddress, srcEthClient)
	if err != nil {
		return errors.Wrap(err, "bridge.NewBridge")
	}

	destBridge, err := bridge.NewBridge(cfg.DestBridgeAddress, destEthClient)
	if err != nil {
		return errors.Wrap(err, "bridge.NewBridge")
	}

	var taikoL1 *taikol1.TaikoL1
	if cfg.SrcTaikoAddress != ZeroAddress {
		taikoL1, err = taikol1.NewTaikoL1(cfg.SrcTaikoAddress, srcEthClient)
		if err != nil {
			return errors.Wrap(err, "taikol1.NewTaikoL1")
		}
	}

	srcChainID, err := srcEthClient.ChainID(context.Background())
	if err != nil {
		return errors.Wrap(err, "srcEthClient.ChainID")
	}

	destChainID, err := destEthClient.ChainID(context.Background())
	if err != nil {
		return errors.Wrap(err, "destEthClient.ChainID")
	}

	i.blockRepo = blockRepository
	i.eventRepo = eventRepository
	i.srcEthClient = srcEthClient

	i.bridge = srcBridge
	i.destBridge = destBridge
	i.taikol1 = taikoL1

	i.blockBatchSize = cfg.BlockBatchSize
	i.numGoroutines = int(cfg.NumGoroutines)
	i.subscriptionBackoff = time.Duration(cfg.SubscriptionBackoff) * time.Second

	i.queue = q

	i.srcChainId = srcChainID
	i.destChainId = destChainID

	i.syncMode = cfg.SyncMode
	i.watchMode = cfg.WatchMode

	i.wg = &sync.WaitGroup{}

	i.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	i.numLatestBlocksToIgnoreWhenCrawling = cfg.NumLatestBlocksToIgnoreWhenCrawling

	return nil
}

func (i *Indexer) Name() string {
	return "indexer"
}

func (i *Indexer) Close(ctx context.Context) {
	i.wg.Wait()
}

// nolint: funlen
func (i *Indexer) Start() error {
	i.ctx = context.Background()

	if err := i.queue.Start(i.ctx, i.queueName()); err != nil {
		return err
	}

	i.wg.Add(1)

	go func() {
		defer func() {
			i.wg.Done()
		}()

		if err := i.filter(i.ctx); err != nil {
			slog.Error("error filtering blocks", "error", err.Error())
		}
	}()

	go func() {
		if err := backoff.Retry(func() error {
			return scanBlocks(i.ctx, i.srcEthClient, i.srcChainId, i.wg)
		}, backoff.NewConstantBackOff(5*time.Second)); err != nil {
			slog.Error("scan blocks backoff retry", "error", err)
		}
	}()

	go func() {
		if err := backoff.Retry(func() error {
			return i.queue.Notify(i.ctx, i.wg)
		}, backoff.NewConstantBackOff(5*time.Second)); err != nil {
			slog.Error("queue notify backoff retry", "error", err)
		}
	}()

	return nil
}

func (i *Indexer) filter(ctx context.Context) error {
	// if subscribing to new events, skip filtering and subscribe
	if i.watchMode == Subscribe {
		return i.subscribe(ctx, i.srcChainId)
	}

	syncMode := i.syncMode

	// always use Resync when crawling past blocks
	if i.watchMode == CrawlPastBlocks {
		syncMode = Resync
	}

	if err := i.setInitialProcessingBlockByMode(ctx, syncMode, i.srcChainId); err != nil {
		return errors.Wrap(err, "i.setInitialProcessingBlockByMode")
	}

	header, err := i.srcEthClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "i.srcEthClient.HeaderByNumber")
	}

	if i.processingBlockHeight == header.Number.Uint64() {
		slog.Info("indexing caught up, subscribing to new incoming events", "chainID", i.srcChainId.Uint64())
		return i.subscribe(ctx, i.srcChainId)
	}

	slog.Info("fetching batch block events",
		"chainID", i.srcChainId.Uint64(),
		"startblock", i.processingBlockHeight,
		"endblock", header.Number.Int64(),
		"batchsize", i.blockBatchSize,
	)

	endBlockID := header.Number.Uint64()

	// ignore latest N blocks, they are probably in queue already
	// and are not "missed".
	if i.watchMode == CrawlPastBlocks {
		endBlockID -= i.numLatestBlocksToIgnoreWhenCrawling
	}

	for j := i.processingBlockHeight; j < endBlockID; j += i.blockBatchSize {
		end := i.processingBlockHeight + i.blockBatchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > endBlockID {
			end = endBlockID
		}

		// filter exclusive of the end block.
		// we use "end" as the next starting point of the batch, and
		// process up to end - 1 for this batch.
		filterEnd := end - 1

		slog.Info("block batch", "start", j, "end", filterEnd)

		filterOpts := &bind.FilterOpts{
			Start:   i.processingBlockHeight,
			End:     &filterEnd,
			Context: ctx,
		}

		// we dont want to watch for message status changed events
		// when crawling past blocks on a loop.
		if i.watchMode != CrawlPastBlocks {
			messageStatusChangedEvents, err := i.bridge.FilterMessageStatusChanged(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "bridge.FilterMessageStatusChanged")
			}

			// we don't need to do anything with msgStatus events except save them to the DB.
			// we don't need to process them. they are for exposing via the API.

			err = i.saveMessageStatusChangedEvents(ctx, i.srcChainId, messageStatusChangedEvents)
			if err != nil {
				return errors.Wrap(err, "bridge.saveMessageStatusChangedEvents")
			}
		}

		messageSentEvents, err := i.bridge.FilterMessageSent(filterOpts, nil)
		if err != nil {
			return errors.Wrap(err, "bridge.FilterMessageSent")
		}

		group, groupCtx := errgroup.WithContext(ctx)
		group.SetLimit(i.numGoroutines)

		for messageSentEvents.Next() {
			event := messageSentEvents.Event

			group.Go(func() error {
				err := i.handleEvent(groupCtx, i.srcChainId, event)
				if err != nil {
					relayer.ErrorEvents.Inc()
					// log error but always return nil to keep other goroutines active
					slog.Error("error handling event", "err", err.Error())
				} else {
					slog.Info("handled event successfully")
				}
				return nil
			})
		}

		// wait for the last of the goroutines to finish
		if err := group.Wait(); err != nil {
			return errors.Wrap(err, "group.Wait")
		}

		// handle no events remaining, saving the processing block and restarting the for
		// loop
		if err := i.handleNoEventsInBatch(ctx, i.srcChainId, int64(end)); err != nil {
			return errors.Wrap(err, "i.handleNoEventsInBatch")
		}
	}

	slog.Info(
		"indexer fully caught up",
	)

	if i.watchMode == CrawlPastBlocks {
		slog.Info("restarting filtering from genesis")
		return i.filter(ctx)
	}

	slog.Info("getting latest block to see if header has advanced")

	latestBlock, err := i.srcEthClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "i.srcEthClient.HeaderByNumber")
	}

	latestBlockIDToCompare := latestBlock.Number.Uint64()

	if i.watchMode == CrawlPastBlocks && latestBlockIDToCompare > i.numLatestBlocksToIgnoreWhenCrawling {
		latestBlockIDToCompare -= i.numLatestBlocksToIgnoreWhenCrawling
	}

	if i.processingBlockHeight < latestBlockIDToCompare {
		slog.Info("header has advanced",
			"processingBlockHeight", i.processingBlockHeight,
			"latestBlock", latestBlockIDToCompare,
		)

		return i.filter(ctx)
	}

	// we are caught up and specified not to subscribe, we can return now
	if i.watchMode == Filter {
		return nil
	}

	slog.Info("processing is caught up to latest block, subscribing to new blocks")

	return i.subscribe(ctx, i.srcChainId)
}

func (i *Indexer) queueName() string {
	return fmt.Sprintf("%v-%v-queue", i.srcChainId.String(), i.destChainId.String())
}
