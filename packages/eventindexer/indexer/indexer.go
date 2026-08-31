package indexer

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	cliV2 "github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/shasta/inbox"
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
	erc20BalanceRepo eventindexer.ERC20BalanceRepository
	txRepo           eventindexer.TransactionRepository

	ethClient  *ethclient.Client
	srcChainID uint64

	// latestIndexedBlockNumber is the last block that has been filtered. Filtering
	// resumes at the block after it, so any block that still needs to be scanned
	// must be greater than this value.
	latestIndexedBlockNumber uint64

	blockBatchSize      uint64
	subscriptionBackoff time.Duration

	bridge *bridge.Bridge
	inbox  *inbox.Inbox

	indexNfts   bool
	indexERC20s bool
	layer       string

	allowUnclaimedBalanceReplay bool

	wg  *sync.WaitGroup
	ctx context.Context

	syncMode SyncMode

	blockSaveMutex *sync.Mutex

	contractToMetadata      map[common.Address]*eventindexer.ERC20Metadata
	contractToMetadataMutex *sync.Mutex
}

func (i *Indexer) Start() error {
	i.ctx = context.Background()

	if err := i.checkBalanceClaimBootstrap(i.ctx); err != nil {
		return err
	}

	if err := i.setInitialIndexingBlockByMode(i.ctx, i.syncMode, i.getFirstShastaBlockHeight); err != nil {
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
			if err := i.filter(ctx); err != nil {
				slog.Error("error filtering", "error", err)
			}
		}
	}
}

func (i *Indexer) Name() string {
	return "indexer"
}

func (i *Indexer) InitFromCli(ctx context.Context, c *cliV2.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, i, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, i *Indexer, cfg *Config) error {
	if err := cfg.validate(); err != nil {
		return err
	}

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

	var inboxContract *inbox.Inbox

	if cfg.Layer == Layer1 {
		slog.Info("setting shastaInboxAddress", "addr", cfg.ShastaInboxAddress.Hex())

		inboxContract, err = inbox.NewInbox(cfg.ShastaInboxAddress, ethClient)
		if err != nil {
			return errors.Wrap(err, "inbox.NewInbox")
		}
	}

	var bridgeContract *bridge.Bridge

	if cfg.BridgeAddress.Hex() != ZeroAddress.Hex() {
		slog.Info("setting bridgeAddress", "addr", cfg.BridgeAddress.Hex())

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
	i.txRepo = txRepository

	i.srcChainID = chainID.Uint64()

	i.ethClient = ethClient
	i.inbox = inboxContract
	i.bridge = bridgeContract
	i.blockBatchSize = cfg.BlockBatchSize
	i.subscriptionBackoff = time.Duration(cfg.SubscriptionBackoff) * time.Second
	i.wg = &sync.WaitGroup{}

	i.syncMode = cfg.SyncMode
	i.indexNfts = cfg.IndexNFTs
	i.allowUnclaimedBalanceReplay = cfg.AllowUnclaimedBalanceReplay
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

// checkBalanceClaimBootstrap refuses to start when this process would replay
// balance mutations that a previous process already applied.
//
// processed_transfer_logs makes replays idempotent, but only for logs claimed at
// least once. Nothing records what a pre-claim process applied, so the indexer
// cannot repair this by itself and the choice belongs to an operator: reset the
// balances so they rebuild from claims, or accept a single overcount.
func (i *Indexer) checkBalanceClaimBootstrap(ctx context.Context) error {
	kinds := []struct {
		kind    string
		enabled bool
	}{
		{eventindexer.TransferKindNFT, i.indexNfts},
		{eventindexer.TransferKindERC20, i.indexERC20s},
	}

	for _, k := range kinds {
		if !k.enabled {
			continue
		}

		atRisk, err := repo.UnclaimedBalanceReplayRisk(ctx, i.db, int64(i.srcChainID), k.kind)
		if err != nil {
			return errors.Wrap(err, "repo.UnclaimedBalanceReplayRisk")
		}

		if !atRisk {
			continue
		}

		if i.allowUnclaimedBalanceReplay {
			slog.Warn("starting with unclaimed balance replay allowed, this restart may double count once",
				"kind", k.kind,
				"chainID", i.srcChainID,
			)

			continue
		}

		return errors.Newf(
			"%s balances for chain %d were written before transfer log claims existed, so this "+
				"restart would replay and double count them once. Either reset those balances so "+
				"they rebuild from claims, or set --allowUnclaimedBalanceReplay / "+
				"ALLOW_UNCLAIMED_BALANCE_REPLAY=true to accept a single overcount",
			k.kind, i.srcChainID,
		)
	}

	return nil
}
