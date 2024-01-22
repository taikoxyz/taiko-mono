package indexer

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/assignmenthook"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/repo"
	"github.com/urfave/cli/v2"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

var (
	Layer1 = "l1"
	Layer2 = "l2"
)

type WatchMode string

var (
	Filter             WatchMode = "filter"
	Subscribe          WatchMode = "subscribe"
	FilterAndSubscribe WatchMode = "filter-and-subscribe"
	WatchModes                   = []WatchMode{Filter, Subscribe, FilterAndSubscribe}
)

type SyncMode string

var (
	Sync   SyncMode = "sync"
	Resync SyncMode = "resync"
	Modes           = []SyncMode{Sync, Resync}
)

type Indexer struct {
	accountRepo        eventindexer.AccountRepository
	blockRepo          eventindexer.BlockRepository
	eventRepo          eventindexer.EventRepository
	processedBlockRepo eventindexer.ProcessedBlockRepository
	statRepo           eventindexer.StatRepository
	nftBalanceRepo     eventindexer.NFTBalanceRepository
	txRepo             eventindexer.TransactionRepository

	ethClient *ethclient.Client

	processingBlockHeight uint64

	blockBatchSize      uint64
	subscriptionBackoff time.Duration

	taikol1        *taikol1.TaikoL1
	bridge         *bridge.Bridge
	assignmentHook *assignmenthook.AssignmentHook
	swaps          []*swap.Swap

	indexNfts bool
	layer     string

	wg  *sync.WaitGroup
	ctx context.Context

	watchMode WatchMode
	syncMode  SyncMode

	blockSaveMutex *sync.Mutex
}

func (indxr *Indexer) Start() error {
	indxr.ctx = context.Background()

	indxr.wg.Add(1)

	go func() {
		defer func() {
			indxr.wg.Done()
		}()

		if err := indxr.filterThenSubscribe(
			indxr.ctx,
			filterFunc,
		); err != nil {
			slog.Error("error filtering and subscribing", "err", err.Error())
		}
	}()

	return nil
}

func (indxr *Indexer) Name() string {
	return "indexer"
}

func (indxr *Indexer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, indxr, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, i *Indexer, cfg *Config) error {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	accountRepository, err := repo.NewAccountRepository(db)
	if err != nil {
		return err
	}

	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return err
	}

	processedBlockRepository, err := repo.NewProcessedBlockRepository(db)
	if err != nil {
		return err
	}

	blockRepository, err := repo.NewBlockRepository(db)
	if err != nil {
		return err
	}

	statRepository, err := repo.NewStatRepository(db)
	if err != nil {
		return err
	}

	nftBalanceRepository, err := repo.NewNFTBalanceRepository(db)
	if err != nil {
		return err
	}

	txRepository, err := repo.NewTransactionRepository(db)
	if err != nil {
		return err
	}

	ethClient, err := ethclient.Dial(cfg.RPCUrl)
	if err != nil {
		return err
	}

	var taikoL1 *taikol1.TaikoL1

	if cfg.L1TaikoAddress.Hex() != ZeroAddress.Hex() {
		taikoL1, err = taikol1.NewTaikoL1(cfg.L1TaikoAddress, ethClient)
		if err != nil {
			return errors.Wrap(err, "contracts.NewTaikoL1")
		}
	}

	var bridgeContract *bridge.Bridge

	if cfg.BridgeAddress.Hex() != ZeroAddress.Hex() {
		bridgeContract, err = bridge.NewBridge(cfg.BridgeAddress, ethClient)
		if err != nil {
			return errors.Wrap(err, "contracts.NewBridge")
		}
	}

	var assignmentHookContract *assignmenthook.AssignmentHook

	if cfg.AssignmentHookAddress.Hex() != ZeroAddress.Hex() {
		assignmentHookContract, err = assignmenthook.NewAssignmentHook(cfg.AssignmentHookAddress, ethClient)
		if err != nil {
			return errors.Wrap(err, "contracts.NewBridge")
		}
	}

	var swapContracts []*swap.Swap

	if cfg.SwapAddresses != nil && len(cfg.SwapAddresses) > 0 {
		for _, v := range cfg.SwapAddresses {
			swapContract, err := swap.NewSwap(v, ethClient)
			if err != nil {
				return errors.Wrap(err, "contracts.NewBridge")
			}

			swapContracts = append(swapContracts, swapContract)
		}
	}

	i.blockSaveMutex = &sync.Mutex{}
	i.accountRepo = accountRepository
	i.eventRepo = eventRepository
	i.processedBlockRepo = processedBlockRepository
	i.statRepo = statRepository
	i.nftBalanceRepo = nftBalanceRepository
	i.txRepo = txRepository
	i.blockRepo = blockRepository

	i.ethClient = ethClient
	i.taikol1 = taikoL1
	i.bridge = bridgeContract
	i.assignmentHook = assignmentHookContract
	i.swaps = swapContracts
	i.blockBatchSize = cfg.BlockBatchSize
	i.subscriptionBackoff = time.Duration(cfg.SubscriptionBackoff) * time.Second
	i.wg = &sync.WaitGroup{}

	i.syncMode = cfg.SyncMode
	i.watchMode = cfg.WatchMode
	i.indexNfts = cfg.IndexNFTs
	i.layer = cfg.Layer

	return nil
}

func (indxr *Indexer) Close(ctx context.Context) {
	indxr.wg.Wait()
}
