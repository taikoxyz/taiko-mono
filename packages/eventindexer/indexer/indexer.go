package indexer

import (
	"context"
	"database/sql"
	stderrors "errors"
	"log/slog"
	"sync"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	cliV2 "github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/repo"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

type SyncMode string

var (
	Sync   SyncMode = "sync"
	Resync SyncMode = "resync"
)

type Indexer struct {
	db db.DB

	writerConn     *sql.Conn
	writerLockName string
	fatalErrors    chan error

	nftCursorRepo  eventindexer.NFTCursorRepository
	nftBalanceRepo eventindexer.NFTBalanceRepository

	ethClient  *ethclient.Client
	srcChainID uint64

	// latestIndexedBlockNumber is the last block that has been filtered. Filtering
	// resumes at the block after it, so any block that still needs to be scanned
	// must be greater than this value.
	latestIndexedBlockNumber uint64

	blockBatchSize uint64

	allowUnclaimedBalanceReplay bool

	wg  *sync.WaitGroup
	ctx context.Context

	syncMode SyncMode
}

func (i *Indexer) Start() (err error) {
	if err = i.acquireWriterLock(i.ctx); err != nil {
		return err
	}

	defer func() {
		if err != nil {
			i.releaseWriterLock()
		}
	}()

	if err := i.checkBalanceClaimBootstrap(i.ctx); err != nil {
		return err
	}

	if err := i.initializeNFTCheckpoint(i.ctx); err != nil {
		return err
	}

	if err := i.setInitialIndexingBlockByMode(i.ctx, i.syncMode); err != nil {
		return errors.Wrap(err, "i.setInitialIndexingBlockByMode")
	}

	i.fatalErrors = make(chan error, 1)
	i.wg.Add(1)

	go i.eventLoop(i.ctx)

	return nil
}

func (i *Indexer) eventLoop(ctx context.Context) {
	defer i.wg.Done()
	defer i.releaseWriterLock()

	t := time.NewTicker(10 * time.Second)

	defer t.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("event loop context done")
			return
		case <-t.C:
			if err := i.checkWriterLock(ctx); err != nil {
				if ctx.Err() != nil {
					return
				}

				slog.Error("stopping indexer after balance writer lock loss", "error", err)
				i.fatalErrors <- err

				return
			}

			if err := i.filter(ctx); err != nil {
				if ctx.Err() != nil {
					return
				}

				slog.Error("error filtering", "error", err)

				if stderrors.Is(err, errWriterLockLost) {
					i.fatalErrors <- err
					return
				}
			}
		}
	}
}

// FatalErrors lets the CLI exit when indexing can no longer continue safely.
// Start initializes the buffered channel before launching the event loop.
func (i *Indexer) FatalErrors() <-chan error { return i.fatalErrors }

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

func InitFromConfig(ctx context.Context, i *Indexer, cfg *Config) error {
	if err := cfg.validate(); err != nil {
		return err
	}

	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	nftCursorRepository, err := repo.NewNFTCursorRepository(db)
	if err != nil {
		return err
	}

	nftBalanceRepository, err := repo.NewNFTBalanceRepository(db)
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

	i.db = db
	i.nftCursorRepo = nftCursorRepository
	i.nftBalanceRepo = nftBalanceRepository

	i.srcChainID = chainID.Uint64()

	i.ethClient = ethClient
	i.blockBatchSize = cfg.BlockBatchSize

	// Cancelled by SubcommandAction once a shutdown signal arrives, so the event
	// loop stops and Close can return.
	i.ctx = ctx
	i.wg = &sync.WaitGroup{}

	i.syncMode = cfg.SyncMode
	i.allowUnclaimedBalanceReplay = cfg.AllowUnclaimedBalanceReplay

	return nil
}

func (i *Indexer) Close(ctx context.Context) {
	i.wg.Wait()

	// Close db connection.
	if err := i.db.Close(); err != nil {
		slog.Error("Failed to close db connection", "err", err)
	}
}

// initializeNFTCheckpoint certifies genesis before the loop or any balance write.
// Legacy business events are a fallback only when NFT state is retained.
func (i *Indexer) initializeNFTCheckpoint(ctx context.Context) error {
	switch i.syncMode {
	case Sync, Resync:
	default:
		return eventindexer.ErrInvalidMode
	}

	balances, claims, checkpoints, _, err := repo.NFTReplayState(ctx, i.db, i.srcChainID)
	if err != nil {
		return err
	}

	if balances == 0 && claims == 0 && checkpoints == 0 {
		if err := i.nftCursorRepo.SaveCheckpoint(ctx, i.srcChainID, 0); err != nil {
			return errors.Wrap(err, "initialize NFT genesis checkpoint")
		}
	}

	return nil
}

// checkBalanceClaimBootstrap rejects retained state for resync and missing
// watermarks for balances. The escape hatch applies only to legacy overlap.
func (i *Indexer) checkBalanceClaimBootstrap(ctx context.Context) error {
	balances, claims, checkpoints, legacy, err := repo.NFTReplayState(ctx, i.db, i.srcChainID)
	if err != nil {
		return err
	}

	if i.syncMode == Resync && (balances > 0 || claims > 0 || checkpoints > 0) {
		if checkpoints > 0 {
			return errors.Newf("NFT resync for chain %d requires a clean rebuild: "+
				"to resume an existing checkpoint, continue with SYNC_MODE=sync; otherwise reconcile and remove chain-scoped "+
				"NFT balances, NFT-kind claims and NFT checkpoint together, then start SYNC_MODE=resync", i.srcChainID)
		}

		return errors.Newf("NFT resync for chain %d has retained NFT state but no trustworthy NFT checkpoint; "+
			"a clean rebuild requires operator reconciliation and removal of chain-scoped NFT balances, NFT-kind claims "+
			"and NFT checkpoint together, then start SYNC_MODE=resync", i.srcChainID)
	}

	if i.syncMode == Sync && claims > 0 && balances == 0 {
		return errors.Newf("missing NFT balances for chain %d with retained NFT claims; "+
			"claimed logs cannot rebuild missing balances. After reconciliation, rebuild by removing chain-scoped "+
			"NFT balances, NFT-kind claims and NFT checkpoint together, then start SYNC_MODE=resync; "+
			"switch to SYNC_MODE=sync only after confirming the NFT checkpoint row", i.srcChainID)
	}

	if i.syncMode == Sync && balances > 0 && checkpoints == 0 && legacy == 0 {
		return errors.Newf("NFT balances for chain %d have no NFT checkpoint or legacy watermark; "+
			"refusing genesis replay regardless of claims or allowUnclaimedBalanceReplay", i.srcChainID)
	}

	if checkpoints > 0 {
		return nil
	}

	atRisk, err := repo.UnclaimedNFTReplayRisk(ctx, i.db, int64(i.srcChainID))
	if err != nil {
		return errors.Wrap(err, "repo.UnclaimedNFTReplayRisk")
	}

	if !atRisk {
		return nil
	}

	if i.allowUnclaimedBalanceReplay {
		slog.Warn("starting with unclaimed NFT replay allowed, this restart may double count once", "chainID", i.srcChainID)
		return nil
	}

	return errors.Newf(
		"NFT balances for chain %d were written before transfer log claims existed, so this "+
			"restart would replay and double count them once. After reconciliation, rebuild by removing chain-scoped NFT balances, "+
			"NFT-kind claims and NFT checkpoint together, then start SYNC_MODE=resync and confirm the NFT checkpoint row "+
			"before switching to SYNC_MODE=sync, or set --allowUnclaimedBalanceReplay / "+
			"ALLOW_UNCLAIMED_BALANCE_REPLAY=true to accept a single overcount",
		i.srcChainID,
	)
}
