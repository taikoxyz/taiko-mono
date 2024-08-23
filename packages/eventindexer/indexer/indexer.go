package indexer

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/repo"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

var (
	Layer1 = "l1"
	Layer2 = "l2"
)

type SyncMode string

var (
	Sync   SyncMode = "sync"
	Resync SyncMode = "resync"
	Modes           = []SyncMode{Sync, Resync}
)

type Indexer struct {
	db db.DB

	accountRepo      eventindexer.AccountRepository
	eventRepo        eventindexer.EventRepository
	nftBalanceRepo   eventindexer.NFTBalanceRepository
	nftMetadataRepo  eventindexer.NFTMetadataRepository
	erc20BalanceRepo eventindexer.ERC20BalanceRepository
	txRepo           eventindexer.TransactionRepository

	ethClient  *ethclient.Client
	srcChainID uint64

	latestIndexedBlockNumber uint64

	blockBatchSize      uint64
	subscriptionBackoff time.Duration

	taikol1 *taikol1.TaikoL1
	bridge  *bridge.Bridge

	indexNfts   bool
	indexERC20s bool
	layer       string

	wg  *sync.WaitGroup
	ctx context.Context

	syncMode SyncMode

	blockSaveMutex *sync.Mutex

	contractToMetadata      map[common.Address]*eventindexer.ERC20Metadata
	contractToMetadataMutex *sync.Mutex
}

func (i *Indexer) Start() error {
	i.ctx = context.Background()

	if err := i.setInitialIndexingBlockByMode(i.ctx, i.syncMode); err != nil {
		return errors.Wrap(err, "i.setInitialIndexingBlockByMode")
	}

	i.wg.Add(1)

	go i.eventLoop(i.ctx)

	return nil
}

func (i *Indexer) eventLoop(ctx context.Context) {
	defer i.wg.Done()

	t := time.NewTicker(10 * time.Second)

	defer t.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("event loop context done")
			return
		case <-t.C:
			if err := i.filter(ctx, filterFunc); err != nil {
				slog.Error("error filtering", "error", err)
			}
		}
	}
}

func (i *Indexer) Name() string {
	return "indexer"
}

func (i *Indexer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, i, cfg)
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

	nftBalanceRepository, err := repo.NewNFTBalanceRepository(db)
	if err != nil {
		return err
	}

	erc20BalanceRepository, err := repo.NewERC20BalanceRepository(db)
	if err != nil {
		return err
	}

	nftMetadataRepository, err := repo.NewNFTMetadataRepository(db)
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

	chainID, err := ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.ChainID()")
	}

	var taikoL1 *taikol1.TaikoL1

	if cfg.L1TaikoAddress.Hex() != ZeroAddress.Hex() {
		slog.Info("setting l1TaikoAddress", "addr", cfg.L1TaikoAddress.Hex())

		taikoL1, err = taikol1.NewTaikoL1(cfg.L1TaikoAddress, ethClient)
		if err != nil {
			return errors.Wrap(err, "contracts.NewTaikoL1")
		}
	}

	var bridgeContract *bridge.Bridge

	if cfg.BridgeAddress.Hex() != ZeroAddress.Hex() {
		slog.Info("setting bridgeADdress", "addr", cfg.BridgeAddress.Hex())

		bridgeContract, err = bridge.NewBridge(cfg.BridgeAddress, ethClient)
		if err != nil {
			return errors.Wrap(err, "contracts.NewBridge")
		}
	}

	i.db = db
	i.blockSaveMutex = &sync.Mutex{}
	i.accountRepo = accountRepository
	i.eventRepo = eventRepository
	i.nftBalanceRepo = nftBalanceRepository
	i.erc20BalanceRepo = erc20BalanceRepository
	i.nftMetadataRepo = nftMetadataRepository
	i.txRepo = txRepository

	i.srcChainID = chainID.Uint64()

	i.ethClient = ethClient
	i.taikol1 = taikoL1
	i.bridge = bridgeContract
	i.blockBatchSize = cfg.BlockBatchSize
	// nolint: gosec
	i.subscriptionBackoff = time.Duration(cfg.SubscriptionBackoff) * time.Second
	i.wg = &sync.WaitGroup{}

	i.syncMode = cfg.SyncMode
	i.indexNfts = cfg.IndexNFTs
	i.indexERC20s = cfg.IndexERC20s
	i.layer = cfg.Layer
	i.contractToMetadata = make(map[common.Address]*eventindexer.ERC20Metadata, 0)
	i.contractToMetadataMutex = &sync.Mutex{}

	return nil
}

func (i *Indexer) Close(ctx context.Context) {
	i.wg.Wait()

	// Close db connection.
	if err := i.db.Close(); err != nil {
		slog.Error("Failed to close db connection", "err", err)
	}
}
