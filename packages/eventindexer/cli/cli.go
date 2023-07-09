package cli

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/labstack/echo/v4"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/joho/godotenv"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/db"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/http"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/indexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/repo"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	envVars = []string{
		"HTTP_PORT",
		"RPC_URL",
		"MYSQL_USER",
		"MYSQL_DATABASE",
		"MYSQL_HOST",
		"PROMETHEUS_HTTP_PORT",
	}

	defaultBlockBatchSize      = 2
	defaultSubscriptionBackoff = 600 * time.Second
)

func Run(
	mode eventindexer.Mode,
	watchMode eventindexer.WatchMode,
	httpOnly eventindexer.HTTPOnly,
) {
	if err := loadAndValidateEnv(); err != nil {
		log.Fatal(err)
	}

	log.SetFormatter(&log.JSONFormatter{})

	db, err := openDBConnection(eventindexer.DBConnectionOpts{
		Name:     os.Getenv("MYSQL_USER"),
		Password: os.Getenv("MYSQL_PASSWORD"),
		Database: os.Getenv("MYSQL_DATABASE"),
		Host:     os.Getenv("MYSQL_HOST"),
		OpenFunc: func(dsn string) (eventindexer.DB, error) {
			gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
				Logger: logger.Default.LogMode(logger.Silent),
			})
			if err != nil {
				return nil, err
			}

			return db.New(gormDB), nil
		},
	})

	if err != nil {
		log.Fatal(err)
	}

	ethClient, err := ethclient.Dial(os.Getenv("RPC_URL"))
	if err != nil {
		log.Fatal(err)
	}

	srv, err := newHTTPServer(db, ethClient)
	if err != nil {
		log.Fatal(err)
	}

	forever := make(chan struct{})

	go func() {
		if err := srv.Start(fmt.Sprintf(":%v", os.Getenv("HTTP_PORT"))); err != nil {
			log.Fatal(err)
		}
	}()

	if !httpOnly {
		eventRepository, err := repo.NewEventRepository(db)
		if err != nil {
			log.Fatal(err)
		}

		statRepository, err := repo.NewStatRepository(db)
		if err != nil {
			log.Fatal(err)
		}

		blockRepository, err := repo.NewBlockRepository(db)
		if err != nil {
			log.Fatal(err)
		}

		blockBatchSize, err := strconv.Atoi(os.Getenv("BLOCK_BATCH_SIZE"))
		if err != nil || blockBatchSize <= 0 {
			blockBatchSize = defaultBlockBatchSize
		}

		var subscriptionBackoff time.Duration

		subscriptionBackoffInSeconds, err := strconv.Atoi(os.Getenv("SUBSCRIPTION_BACKOFF_IN_SECONDS"))
		if err != nil || subscriptionBackoffInSeconds <= 0 {
			subscriptionBackoff = defaultSubscriptionBackoff
		} else {
			subscriptionBackoff = time.Duration(subscriptionBackoffInSeconds) * time.Second
		}

		rpcClient, err := rpc.DialContext(context.Background(), os.Getenv("RPC_URL"))
		if err != nil {
			log.Fatal(err)
		}

		i, err := indexer.NewService(indexer.NewServiceOpts{
			EventRepo:           eventRepository,
			BlockRepo:           blockRepository,
			StatRepo:            statRepository,
			EthClient:           ethClient,
			RPCClient:           rpcClient,
			SrcTaikoAddress:     common.HexToAddress(os.Getenv("L1_TAIKO_ADDRESS")),
			SrcBridgeAddress:    common.HexToAddress(os.Getenv("BRIDGE_ADDRESS")),
			SrcSwapAddresses:    stringsToAddresses(strings.Split(os.Getenv("SWAP_ADDRESSES"), ",")),
			BlockBatchSize:      uint64(blockBatchSize),
			SubscriptionBackoff: subscriptionBackoff,
		})
		if err != nil {
			log.Fatal(err)
		}

		var filterFunc indexer.FilterFunc = indexer.L1FilterFunc

		if os.Getenv("L1_TAIKO_ADDRESS") == "" {
			filterFunc = indexer.L2FilterFunc
		}

		go func() {
			if err := i.FilterThenSubscribe(context.Background(), mode, watchMode, filterFunc); err != nil {
				log.Fatal(err)
			}
		}()
	}

	<-forever
}

func stringsToAddresses(s []string) []common.Address {
	a := []common.Address{}

	for _, v := range s {
		if v != "" {
			a = append(a, common.HexToAddress(v))
		}
	}

	return a
}

func openDBConnection(opts eventindexer.DBConnectionOpts) (eventindexer.DB, error) {
	dsn := ""
	if opts.Password == "" {
		dsn = fmt.Sprintf(
			"%v@tcp(%v)/%v?charset=utf8mb4&parseTime=True&loc=Local",
			opts.Name,
			opts.Host,
			opts.Database,
		)
	} else {
		dsn = fmt.Sprintf(
			"%v:%v@tcp(%v)/%v?charset=utf8mb4&parseTime=True&loc=Local",
			opts.Name,
			opts.Password,
			opts.Host,
			opts.Database,
		)
	}

	db, err := opts.OpenFunc(dsn)
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	var (
		defaultMaxIdleConns    = 50
		defaultMaxOpenConns    = 200
		defaultConnMaxLifetime = 10 * time.Second
	)

	maxIdleConns, err := strconv.Atoi(os.Getenv("MYSQL_MAX_IDLE_CONNS"))
	if err != nil || maxIdleConns <= 0 {
		maxIdleConns = defaultMaxIdleConns
	}

	maxOpenConns, err := strconv.Atoi(os.Getenv("MYSQL_MAX_OPEN_CONNS"))
	if err != nil || maxOpenConns <= 0 {
		maxOpenConns = defaultMaxOpenConns
	}

	var maxLifetime time.Duration

	connMaxLifetime, err := strconv.Atoi(os.Getenv("MYSQL_CONN_MAX_LIFETIME_IN_MS"))
	if err != nil || connMaxLifetime <= 0 {
		maxLifetime = defaultConnMaxLifetime
	} else {
		maxLifetime = time.Duration(connMaxLifetime)
	}

	// SetMaxOpenConns sets the maximum number of open connections to the database.
	sqlDB.SetMaxOpenConns(maxOpenConns)

	// SetMaxIdleConns sets the maximum number of connections in the idle connection pool.
	sqlDB.SetMaxIdleConns(maxIdleConns)

	// SetConnMaxLifetime sets the maximum amount of time a connection may be reused.
	sqlDB.SetConnMaxLifetime(maxLifetime)

	return db, nil
}

func loadAndValidateEnv() error {
	_ = godotenv.Load()

	missing := make([]string, 0)

	for _, v := range envVars {
		e := os.Getenv(v)
		if e == "" {
			missing = append(missing, v)
		}
	}

	if len(missing) == 0 {
		return nil
	}

	return errors.Errorf("Missing env vars: %v", missing)
}

func newHTTPServer(db eventindexer.DB, l1EthClient *ethclient.Client) (*http.Server, error) {
	eventRepo, err := repo.NewEventRepository(db)
	if err != nil {
		return nil, err
	}

	statRepo, err := repo.NewStatRepository(db)
	if err != nil {
		return nil, err
	}

	srv, err := http.NewServer(http.NewServerOpts{
		EventRepo:   eventRepo,
		StatRepo:    statRepo,
		Echo:        echo.New(),
		CorsOrigins: strings.Split(os.Getenv("CORS_ORIGINS"), ","),
	})
	if err != nil {
		return nil, err
	}

	return srv, nil
}
