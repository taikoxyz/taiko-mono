package cli

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/labstack/echo/v4"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/joho/godotenv"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/db"
	"github.com/taikoxyz/taiko-mono/packages/relayer/http"
	"github.com/taikoxyz/taiko-mono/packages/relayer/indexer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/repo"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	envVars = []string{
		"HTTP_PORT",
		"L1_BRIDGE_ADDRESS",
		"L2_BRIDGE_ADDRESS",
		"L2_TAIKO_ADDRESS",
		"L1_RPC_URL",
		"L2_RPC_URL",
		"MYSQL_USER",
		"MYSQL_DATABASE",
		"MYSQL_HOST",
		"RELAYER_ECDSA_KEY",
		"CONFIRMATIONS_BEFORE_PROCESSING",
		"PROMETHEUS_HTTP_PORT",
	}

	defaultBlockBatchSize                = 2
	defaultNumGoroutines                 = 10
	defaultSubscriptionBackoff           = 600 * time.Second
	defaultConfirmations                 = 15
	defaultHeaderSyncIntervalSeconds int = 60
)

func Run(
	mode relayer.Mode,
	watchMode relayer.WatchMode,
	layer relayer.Layer,
	httpOnly relayer.HTTPOnly,
	profitableOnly relayer.ProfitableOnly,
) {
	if err := loadAndValidateEnv(); err != nil {
		log.Fatal(err)
	}

	log.SetFormatter(&log.JSONFormatter{})

	db, err := openDBConnection(relayer.DBConnectionOpts{
		Name:     os.Getenv("MYSQL_USER"),
		Password: os.Getenv("MYSQL_PASSWORD"),
		Database: os.Getenv("MYSQL_DATABASE"),
		Host:     os.Getenv("MYSQL_HOST"),
		OpenFunc: func(dsn string) (relayer.DB, error) {
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

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatal(err)
	}

	l1EthClient, err := ethclient.Dial(os.Getenv("L1_RPC_URL"))
	if err != nil {
		log.Fatal(err)
	}

	l2EthClient, err := ethclient.Dial(os.Getenv("L2_RPC_URL"))
	if err != nil {
		log.Fatal(err)
	}

	srv, err := newHTTPServer(db, l1EthClient, l2EthClient)
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
		indexers, closeFunc, err := makeIndexers(layer, db, profitableOnly)
		if err != nil {
			sqlDB.Close()
			log.Fatal(err)
		}

		defer sqlDB.Close()
		defer closeFunc()

		for _, i := range indexers {
			go func(i *indexer.Service) {
				if err := i.FilterThenSubscribe(context.Background(), mode, watchMode); err != nil {
					log.Fatal(err)
				}
			}(i)
		}
	}

	<-forever
}

func makeIndexers(
	layer relayer.Layer,
	db relayer.DB,
	profitableOnly relayer.ProfitableOnly,
) ([]*indexer.Service, func(), error) {
	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return nil, nil, err
	}

	blockRepository, err := repo.NewBlockRepository(db)
	if err != nil {
		return nil, nil, err
	}

	blockBatchSize, err := strconv.Atoi(os.Getenv("BLOCK_BATCH_SIZE"))
	if err != nil || blockBatchSize <= 0 {
		blockBatchSize = defaultBlockBatchSize
	}

	numGoroutines, err := strconv.Atoi(os.Getenv("NUM_GOROUTINES"))
	if err != nil || numGoroutines <= 0 {
		numGoroutines = defaultNumGoroutines
	}

	var subscriptionBackoff time.Duration

	subscriptionBackoffInSeconds, err := strconv.Atoi(os.Getenv("SUBSCRIPTION_BACKOFF_IN_SECONDS"))
	if err != nil || subscriptionBackoffInSeconds <= 0 {
		subscriptionBackoff = defaultSubscriptionBackoff
	} else {
		subscriptionBackoff = time.Duration(subscriptionBackoffInSeconds) * time.Second
	}

	headerSyncIntervalInSeconds, err := strconv.Atoi(os.Getenv("HEADER_SYNC_INTERVAL_IN_SECONDS"))
	if err != nil || headerSyncIntervalInSeconds <= 0 {
		headerSyncIntervalInSeconds = defaultHeaderSyncIntervalSeconds
	}

	confirmations, err := strconv.Atoi(os.Getenv("CONFIRMATIONS_BEFORE_PROCESSING"))
	if err != nil || confirmations <= 0 {
		confirmations = defaultConfirmations
	}

	l1EthClient, err := ethclient.Dial(os.Getenv("L1_RPC_URL"))
	if err != nil {
		log.Fatal(err)
	}

	l2EthClient, err := ethclient.Dial(os.Getenv("L2_RPC_URL"))
	if err != nil {
		log.Fatal(err)
	}

	l1RpcClient, err := rpc.DialContext(context.Background(), os.Getenv("L1_RPC_URL"))
	if err != nil {
		return nil, nil, err
	}

	l2RpcClient, err := rpc.DialContext(context.Background(), os.Getenv("L2_RPC_URL"))
	if err != nil {
		return nil, nil, err
	}

	indexers := make([]*indexer.Service, 0)

	if layer == relayer.L1 || layer == relayer.Both {
		l1Indexer, err := indexer.NewService(indexer.NewServiceOpts{
			EventRepo:     eventRepository,
			BlockRepo:     blockRepository,
			DestEthClient: l2EthClient,
			EthClient:     l1EthClient,
			RPCClient:     l1RpcClient,
			DestRPCClient: l2RpcClient,

			ECDSAKey:                    os.Getenv("RELAYER_ECDSA_KEY"),
			BridgeAddress:               common.HexToAddress(os.Getenv("L1_BRIDGE_ADDRESS")),
			DestBridgeAddress:           common.HexToAddress(os.Getenv("L2_BRIDGE_ADDRESS")),
			DestTaikoAddress:            common.HexToAddress(os.Getenv("L2_TAIKO_ADDRESS")),
			SrcTaikoAddress:             common.HexToAddress(os.Getenv("L1_TAIKO_ADDRESS")),
			SrcSignalServiceAddress:     common.HexToAddress(os.Getenv("L1_SIGNAL_SERVICE_ADDRESS")),
			BlockBatchSize:              uint64(blockBatchSize),
			NumGoroutines:               numGoroutines,
			SubscriptionBackoff:         subscriptionBackoff,
			Confirmations:               uint64(confirmations),
			ProfitableOnly:              profitableOnly,
			HeaderSyncIntervalInSeconds: int64(headerSyncIntervalInSeconds),
		})
		if err != nil {
			log.Fatal(err)
		}

		indexers = append(indexers, l1Indexer)
	}

	if layer == relayer.L2 || layer == relayer.Both {
		l2Indexer, err := indexer.NewService(indexer.NewServiceOpts{
			EventRepo:     eventRepository,
			BlockRepo:     blockRepository,
			DestEthClient: l1EthClient,
			EthClient:     l2EthClient,
			RPCClient:     l2RpcClient,
			DestRPCClient: l1RpcClient,

			ECDSAKey:                    os.Getenv("RELAYER_ECDSA_KEY"),
			BridgeAddress:               common.HexToAddress(os.Getenv("L2_BRIDGE_ADDRESS")),
			DestBridgeAddress:           common.HexToAddress(os.Getenv("L1_BRIDGE_ADDRESS")),
			DestTaikoAddress:            common.HexToAddress(os.Getenv("L1_TAIKO_ADDRESS")),
			SrcSignalServiceAddress:     common.HexToAddress(os.Getenv("L2_SIGNAL_SERVICE_ADDRESS")),
			BlockBatchSize:              uint64(blockBatchSize),
			NumGoroutines:               numGoroutines,
			SubscriptionBackoff:         subscriptionBackoff,
			Confirmations:               uint64(confirmations),
			ProfitableOnly:              profitableOnly,
			HeaderSyncIntervalInSeconds: int64(headerSyncIntervalInSeconds),
		})
		if err != nil {
			log.Fatal(err)
		}

		indexers = append(indexers, l2Indexer)
	}

	closeFunc := func() {
		l1EthClient.Close()
		l2EthClient.Close()
		l1RpcClient.Close()
		l2RpcClient.Close()
	}

	return indexers, closeFunc, nil
}

func openDBConnection(opts relayer.DBConnectionOpts) (relayer.DB, error) {
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

func newHTTPServer(db relayer.DB, l1EthClient relayer.EthClient, l2EthClient relayer.EthClient) (*http.Server, error) {
	eventRepo, err := repo.NewEventRepository(db)
	if err != nil {
		return nil, err
	}

	blockRepo, err := repo.NewBlockRepository(db)
	if err != nil {
		return nil, err
	}

	srv, err := http.NewServer(http.NewServerOpts{
		EventRepo:   eventRepo,
		Echo:        echo.New(),
		CorsOrigins: strings.Split(os.Getenv("CORS_ORIGINS"), ","),
		L1EthClient: l1EthClient,
		L2EthClient: l2EthClient,
		BlockRepo:   blockRepo,
	})
	if err != nil {
		return nil, err
	}

	return srv, nil
}
