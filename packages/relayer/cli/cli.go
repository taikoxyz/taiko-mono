package cli

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rpc"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/joho/godotenv"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/indexer"
	"github.com/taikochain/taiko-mono/packages/relayer/repo"
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
	}

	defaultBlockBatchSize      = 2
	defaultNumGoroutines       = 10
	defaultSubscriptionBackoff = 2 * time.Second
)

func Run(mode relayer.Mode, layer relayer.Layer) {
	if err := loadAndValidateEnv(); err != nil {
		log.Fatal(err)
	}

	log.SetFormatter(&log.JSONFormatter{})

	db := openDBConnection(relayer.DBConnectionOpts{
		Name:     os.Getenv("MYSQL_USER"),
		Password: os.Getenv("MYSQL_PASSWORD"),
		Database: os.Getenv("MYSQL_DATABASE"),
		Host:     os.Getenv("MYSQL_HOST"),
	})

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatal(err)
	}

	indexers, closeFunc, err := makeIndexers(layer, db)
	if err != nil {
		sqlDB.Close()
		log.Fatal(err)
	}

	defer sqlDB.Close()
	defer closeFunc()

	forever := make(chan struct{})

	for _, i := range indexers {
		go func(i *indexer.Service) {
			if err := i.FilterThenSubscribe(context.Background(), mode); err != nil {
				log.Fatal(err)
			}
		}(i)
	}

	<-forever
}

func makeIndexers(layer relayer.Layer, db *gorm.DB) ([]*indexer.Service, func(), error) {
	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return nil, nil, err
	}

	blockRepository, err := repo.NewBlockRepository(db)
	if err != nil {
		return nil, nil, err
	}

	l1EthClient, err := ethclient.Dial(os.Getenv("L1_RPC_URL"))
	if err != nil {
		return nil, nil, err
	}

	l2EthClient, err := ethclient.Dial(os.Getenv("L2_RPC_URL"))
	if err != nil {
		return nil, nil, err
	}

	l1RpcClient, err := rpc.DialContext(context.Background(), os.Getenv("L1_RPC_URL"))
	if err != nil {
		return nil, nil, err
	}

	l2RpcClient, err := rpc.DialContext(context.Background(), os.Getenv("L2_RPC_URL"))
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
	if err != nil || numGoroutines <= 0 {
		subscriptionBackoff = defaultSubscriptionBackoff
	} else {
		subscriptionBackoff = time.Duration(subscriptionBackoffInSeconds) * time.Second
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

			ECDSAKey:          os.Getenv("RELAYER_ECDSA_KEY"),
			BridgeAddress:     common.HexToAddress(os.Getenv("L1_BRIDGE_ADDRESS")),
			DestBridgeAddress: common.HexToAddress(os.Getenv("L2_BRIDGE_ADDRESS")),
			DestTaikoAddress:  common.HexToAddress(os.Getenv("L2_TAIKO_ADDRESS")),

			BlockBatchSize:      uint64(blockBatchSize),
			NumGoroutines:       numGoroutines,
			SubscriptionBackoff: subscriptionBackoff,
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

			ECDSAKey:          os.Getenv("RELAYER_ECDSA_KEY"),
			BridgeAddress:     common.HexToAddress(os.Getenv("L2_BRIDGE_ADDRESS")),
			DestBridgeAddress: common.HexToAddress(os.Getenv("L1_BRIDGE_ADDRESS")),
			DestTaikoAddress:  common.HexToAddress(os.Getenv("L1_TAIKO_ADDRESS")),

			BlockBatchSize:      uint64(blockBatchSize),
			NumGoroutines:       numGoroutines,
			SubscriptionBackoff: subscriptionBackoff,
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

func openDBConnection(opts relayer.DBConnectionOpts) *gorm.DB {
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

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		log.Fatal(err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatal(err)
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

	return db
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
