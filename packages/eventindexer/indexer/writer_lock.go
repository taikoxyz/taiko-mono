package indexer

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/repo"
)

var errWriterLockLost = errors.New("balance writer lock lost")

// writerLockKey includes the database because MySQL named locks are server-wide.
// The 120-bit database digest leaves room for the largest uint64 chain ID within
// MySQL's 64-byte lock-name limit.
func writerLockKey(chainID uint64, database string) string {
	digest := sha256.Sum256([]byte(database))
	return fmt.Sprintf("eventindexer:%d:%x", chainID, digest[:15])
}

func (i *Indexer) acquireWriterLock(ctx context.Context) (err error) {
	if !i.indexNfts && !i.indexERC20s {
		return nil
	}

	if i.writerConn != nil {
		return errors.New("balance writer lock already acquired")
	}

	pool, err := i.db.DB()

	if err != nil {
		return fmt.Errorf("writer database: %w", err)
	}

	if pool.Stats().MaxOpenConnections == 1 {
		return errors.New("balance writer requires MaxOpenConns greater than 1 or unlimited")
	}

	conn, err := pool.Conn(ctx)
	if err != nil {
		return fmt.Errorf("reserve balance writer session: %w", err)
	}

	i.writerConn = conn

	defer func() {
		if err != nil {
			i.releaseWriterLock()
		}
	}()

	var database sql.NullString

	if err = conn.QueryRowContext(ctx, "SELECT DATABASE()").Scan(&database); err != nil {
		return fmt.Errorf("writer database name: %w", err)
	}

	if !database.Valid || database.String == "" {
		return errors.New("balance writer requires a selected database")
	}

	i.writerLockName = writerLockKey(i.srcChainID, database.String)

	var acquired sql.NullInt64

	if err = conn.QueryRowContext(ctx, "SELECT GET_LOCK(?, 0)", i.writerLockName).Scan(&acquired); err != nil {
		return fmt.Errorf("acquire balance writer lock: %w", err)
	}

	if !acquired.Valid || acquired.Int64 != 1 {
		return fmt.Errorf("balance writer lock %q already held or unavailable", i.writerLockName)
	}
	// Session clones Config and (with Context set) Statement. Both pools must
	// point at the reserved connection, including transaction BeginTx calls.
	// Keep i.db and the account/event/transaction repositories on their usual pool.
	pinned := i.db.GormDB().Session(&gorm.Session{NewDB: true, Context: ctx})
	pinned.ConnPool = conn
	pinned.Statement.ConnPool = conn
	pinnedDB := db.New(pinned)
	nft, err := repo.NewNFTBalanceRepository(pinnedDB)

	if err != nil {
		return err
	}

	erc20, err := repo.NewERC20BalanceRepository(pinnedDB)

	if err != nil {
		return err
	}

	i.nftBalanceRepo = nft
	i.erc20BalanceRepo = erc20

	return nil
}

func (i *Indexer) checkWriterLock(ctx context.Context) error {
	if !i.indexNfts && !i.indexERC20s {
		return nil
	}

	if i.writerConn == nil {
		return errWriterLockLost
	}

	var owned sql.NullBool
	err := i.writerConn.QueryRowContext(ctx,
		"SELECT IS_USED_LOCK(?) = CONNECTION_ID()", i.writerLockName).Scan(&owned)

	if err != nil {
		return fmt.Errorf("%w: %v", errWriterLockLost, err)
	}

	if !owned.Valid || !owned.Bool {
		return errWriterLockLost
	}

	return nil
}

func (i *Indexer) releaseWriterLock() {
	if i.writerConn == nil {
		return
	}

	conn := i.writerConn
	i.writerConn = nil
	// Shutdown and failed startup commonly have a cancelled caller context.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var released sql.NullInt64
	if err := conn.QueryRowContext(ctx, "SELECT RELEASE_LOCK(?)", i.writerLockName).Scan(&released); err != nil {
		slog.Warn("release balance writer lock failed", "error", err)
	}
	// Never return this physical session to the pool: even if RELEASE_LOCK fails,
	// closing the underlying connection releases its session-scoped named locks.
	if err := conn.Raw(func(any) error { return driver.ErrBadConn }); err != nil &&
		!errors.Is(err, driver.ErrBadConn) && !errors.Is(err, sql.ErrConnDone) {
		slog.Warn("discard balance writer session failed", "error", err)
	}

	if err := conn.Close(); err != nil && !errors.Is(err, sql.ErrConnDone) {
		slog.Warn("close balance writer session failed", "error", err)
	}

	i.writerLockName = ""
}
