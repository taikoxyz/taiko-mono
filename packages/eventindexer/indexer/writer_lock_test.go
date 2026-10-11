package indexer

import (
	"context"
	"fmt"
	"math"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/pressly/goose/v3"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func TestWriterLockKey(t *testing.T) {
	key := writerLockKey(math.MaxUint64, strings.Repeat("database", 100))
	require.LessOrEqual(t, len(key), 64)
	require.Equal(t, key, writerLockKey(math.MaxUint64, strings.Repeat("database", 100)))
	require.NotEqual(t, key, writerLockKey(1, strings.Repeat("database", 100)))
	require.NotEqual(t, writerLockKey(1, "a"), writerLockKey(1, "b"))
}

func TestIntegration_WriterLock(t *testing.T) {
	ctx := context.Background()
	c, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: testcontainers.ContainerRequest{
			Image: "mysql:latest", ExposedPorts: []string{"3306/tcp"},
			Env:        map[string]string{"MYSQL_ROOT_PASSWORD": "password", "MYSQL_DATABASE": "indexer"},
			WaitingFor: wait.ForLog("ready for connections").WithOccurrence(2).WithStartupTimeout(2 * time.Minute),
		}, Started: true,
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		stopCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
		defer cancel()
		require.NoError(t, c.Terminate(stopCtx))
	})

	host, err := c.Host(ctx)
	require.NoError(t, err)
	port, err := c.MappedPort(ctx, "3306/tcp")
	require.NoError(t, err)

	open := func(database string) db.DB {
		var g *gorm.DB

		var openErr error

		require.Eventually(t, func() bool {
			dsn := fmt.Sprintf("root:password@tcp(%s:%d)/%s?parseTime=true&timeout=10s&readTimeout=10s&writeTimeout=10s",
				host, port.Num(), database)
			g, openErr = gorm.Open(mysql.Open(dsn), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})

			return openErr == nil
		}, 2*time.Minute, time.Second)

		d := db.New(g)

		t.Cleanup(func() { require.NoError(t, d.Close()) })

		return d
	}
	d := open("indexer")
	pool, err := d.DB()
	require.NoError(t, err)
	require.NoError(t, goose.SetDialect("mysql"))
	require.NoError(t, goose.Up(pool, "../migrations"))
	require.NoError(t, d.GormDB().Exec("CREATE DATABASE other_indexer").Error)

	other := open("other_indexer")
	makeIndexer := func(database db.DB, chain uint64) *Indexer {
		return &Indexer{db: database, srcChainID: chain, ctx: ctx, wg: &sync.WaitGroup{}, syncMode: Resync}
	}
	a := makeIndexer(d, 1)
	require.NoError(t, a.acquireWriterLock(ctx))
	t.Cleanup(a.releaseWriterLock)

	b := makeIndexer(d, 1)
	require.ErrorContains(t, b.acquireWriterLock(ctx), "already held")
	require.Nil(t, b.writerConn)

	cursor := &initialNFTCursorRepository{}
	b.nftCursorRepo = cursor
	b.syncMode = Sync
	require.ErrorContains(t, b.Start(), "already held")
	require.Zero(t, cursor.calls)

	chain := makeIndexer(d, 2)
	require.NoError(t, chain.acquireWriterLock(ctx))
	chain.releaseWriterLock()

	database := makeIndexer(other, 1)
	require.NoError(t, database.acquireWriterLock(ctx))
	database.releaseWriterLock()
	require.NoError(t, a.checkWriterLock(ctx))
	// The ordinary pool retains its original connection configuration.
	require.Equal(t, pool, d.GormDB().ConnPool)
	a.releaseWriterLock()
	require.NoError(t, b.acquireWriterLock(ctx))
	b.releaseWriterLock()
	// Invalid mode fails after bootstrap and must return the writer session.
	failed := makeIndexer(d, 1)
	failed.syncMode = SyncMode("invalid")
	require.Error(t, failed.Start())
	require.Nil(t, failed.writerConn)
	require.NoError(t, b.acquireWriterLock(ctx))
	b.releaseWriterLock()
	// Bootstrap queries fail on the isolated database without indexer tables.
	// This failure must release the session before cursor work can run.
	bootstrap := makeIndexer(other, 99)
	require.ErrorContains(t, bootstrap.Start(), "count processed_transfer_logs")
	require.Nil(t, bootstrap.writerConn)

	replacement := makeIndexer(other, 99)
	require.NoError(t, replacement.acquireWriterLock(ctx))
	replacement.releaseWriterLock()
	// Shutdown cleanup happens before waiters are released.
	shutdownCtx, cancel := context.WithCancel(ctx)
	running := makeIndexer(d, 1)
	running.ctx = shutdownCtx
	require.NoError(t, running.Start())
	cancel()
	running.wg.Wait()
	require.Nil(t, running.writerConn)
	require.NoError(t, b.acquireWriterLock(ctx))
	b.releaseWriterLock()
	// Kill the physical session, then exercise the actual balance repository.
	lost := makeIndexer(d, 1)
	require.NoError(t, lost.acquireWriterLock(ctx))

	defer lost.releaseWriterLock()

	ref := func(kind string, index uint) eventindexer.TransferLogRef {
		return eventindexer.TransferLogRef{ChainID: 1, Kind: kind, TxHash: "0x" + strings.Repeat("a", 64), LogIndex: index}
	}
	nftOpts := eventindexer.UpdateNFTBalanceOpts{ChainID: 1, ContractAddress: "0x123", Address: "0x456", Amount: 1}
	nftBalance, _, err := lost.nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx,
		ref(eventindexer.TransferKindNFT, 2), nftOpts, eventindexer.UpdateNFTBalanceOpts{})
	require.NoError(t, err)
	require.EqualValues(t, 1, nftBalance.Amount)

	var id uint64

	require.NoError(t, lost.writerConn.QueryRowContext(ctx, "SELECT CONNECTION_ID()").Scan(&id))
	require.NoError(t, d.GormDB().Exec(fmt.Sprintf("KILL CONNECTION %d", id)).Error)
	require.ErrorIs(t, lost.checkWriterLock(ctx), errWriterLockLost)
	_, _, err = lost.nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx,
		ref(eventindexer.TransferKindNFT, 4),
		nftOpts,
		eventindexer.UpdateNFTBalanceOpts{})
	require.Error(t, err)
	// A batch stops before requesting RPC data after ownership is lost.
	require.ErrorIs(t, lost.filter(ctx), errWriterLockLost)

	var claims int64

	require.NoError(t, d.GormDB().Table("processed_transfer_logs").Count(&claims).Error)
	require.EqualValues(t, 1, claims)
	require.NoError(t, d.GormDB().First(nftBalance, nftBalance.ID).Error)
	require.EqualValues(t, 1, nftBalance.Amount)
	require.NoError(t, b.acquireWriterLock(ctx))
	b.releaseWriterLock()
	// Fatal ownership loss exits the loop, notifies the CLI, and cleans up
	// before the wait group completes. Use the real loop's existing10-second tick.
	lost.fatalErrors = make(chan error, 1)
	loopCtx, stopLoop := context.WithCancel(ctx)

	defer stopLoop()

	lost.wg.Add(1)

	go lost.eventLoop(loopCtx)

	select {
	case fatal := <-lost.FatalErrors():
		require.ErrorIs(t, fatal, errWriterLockLost)
	case <-time.After(15 * time.Second):
		t.Fatal("event loop did not report writer lock loss")
	}
	lost.wg.Wait()
	require.Nil(t, lost.writerConn)
	// Reserving the only connection would strand bootstrap/cursor work.
	pool.SetMaxOpenConns(1)
	require.ErrorContains(t, makeIndexer(d, 3).acquireWriterLock(ctx), "MaxOpenConns")
	pool.SetMaxOpenConns(0)
}
