package tests

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/pressly/goose/v3"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/indexer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue/rabbitmq"
	"github.com/taikoxyz/taiko-mono/packages/relayer/processor"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func newTestIndexer(t *testing.T, ctx context.Context) *indexer.Indexer {
	i := &indexer.Indexer{}

	queuePort, _ := strconv.Atoi(os.Getenv("QUEUE_PORT"))
	err :=
		indexer.InitFromConfig(
			ctx,
			i,
			&indexer.Config{
				SrcBridgeAddress:                    common.HexToAddress(os.Getenv("SRC_BRIDGE_ADDRESS")),
				SrcTaikoAddress:                     common.HexToAddress(os.Getenv("SRC_TAIKO_ADDRESS")),
				SrcSignalServiceAddress:             common.HexToAddress(os.Getenv("SRC_SIGNAL_SERVICE_ADDRESS")),
				DestBridgeAddress:                   common.HexToAddress(os.Getenv("DEST_BRIDGE_ADDRESS")),
				DatabaseUsername:                    os.Getenv("DATABASE_USER"),
				DatabasePassword:                    os.Getenv("DATABASE_PASSWORD"),
				DatabaseName:                        os.Getenv("DATABASE_NAME"),
				DatabaseHost:                        os.Getenv("DATABASE_HOST"),
				DatabaseMaxIdleConns:                5,
				DatabaseMaxOpenConns:                5,
				DatabaseMaxConnLifetime:             10000,
				QueueUsername:                       os.Getenv("QUEUE_USER"),
				QueuePassword:                       os.Getenv("QUEUE_PASSWORD"),
				QueueHost:                           os.Getenv("QUEUE_HOST"),
				QueuePort:                           uint64(queuePort),
				SrcRPCUrl:                           os.Getenv("SRC_RPC_URL"),
				DestRPCUrl:                          os.Getenv("DEST_RPC_URL"),
				BlockBatchSize:                      5,
				NumGoroutines:                       5,
				SubscriptionBackoff:                 5,
				WatchMode:                           indexer.Filter,
				SyncMode:                            indexer.Sync,
				ETHClientTimeout:                    1000,
				NumLatestBlocksToIgnoreWhenCrawling: 0,
				EventName:                           relayer.EventNameMessageSent,
				BackOffMaxRetries:                   3,
				BackOffRetryInterval:                1 * time.Second,
				TargetBlockNumber: func() *uint64 {
					return nil
				}(),
				OpenDBFunc: func() (indexer.DB, error) {
					return db.OpenDBConnection(db.DBConnectionOpts{
						Name:            os.Getenv("DATABASE_USER"),
						Password:        os.Getenv("DATABASE_PASSWORD"),
						Database:        os.Getenv("DATABASE_NAME"),
						Host:            os.Getenv("DATABASE_HOST"),
						MaxIdleConns:    5,
						MaxOpenConns:    5,
						MaxConnLifetime: 5,
						OpenFunc: func(dsn string) (*db.DB, error) {
							gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
								Logger: logger.Default.LogMode(logger.Silent),
							})
							if err != nil {
								return nil, err
							}

							return db.New(gormDB), nil
						},
					})
				},
				OpenQueueFunc: func() (queue.Queue, error) {
					opts := queue.NewQueueOpts{
						Username: os.Getenv("QUEUE_USER"),
						Password: os.Getenv("QUEUE_PASSWORD"),
						Host:     os.Getenv("QUEUE_HOST"),
						Port:     os.Getenv("QUEUE_PORT"),
					}

					q, err := rabbitmq.NewQueue(opts)
					if err != nil {
						return nil, err
					}

					return q, nil
				},
			},
		)

	if err != nil {
		t.Fatal(err)
	}

	return i
}

func newTestProcessor() (*processor.Processor, error) {
	return nil, nil
}

func runMigrations(t *testing.T) func() {
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s)/%s?tls=skip-verify&parseTime=true&multiStatements=true",
		os.Getenv("DATABASE_USER"),
		os.Getenv("DATABASE_PASSWORD"),
		os.Getenv("DATABASE_HOST"),
		os.Getenv("DATABASE_NAME"),
	)

	gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}

	if err := goose.SetDialect("mysql"); err != nil {
		t.Fatal(err)
	}

	sqlDB, _ := gormDB.DB()
	if err := goose.Up(sqlDB, "../../migrations"); err != nil {
		t.Fatal(err)
	}

	return func() {
		if err := goose.DownTo(sqlDB, "../../migrations", 0); err != nil {
			t.Fatal(err)
		}
	}
}

func Test_E2E(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	defer cancel()

	i := newTestIndexer(t, ctx)

	downMigs := runMigrations(t)

	defer downMigs()

	assert.Nil(t, i.Start())

	srcEthClient, err := ethclient.Dial(os.Getenv("SRC_RPC_URL"))
	assert.Nil(t, err)

	srcChainID, err := srcEthClient.ChainID(ctx)
	assert.Nil(t, err)

	destEthClient, err := ethclient.Dial(os.Getenv("DEST_RPC_URL"))
	assert.Nil(t, err)

	destChainID, err := destEthClient.ChainID(ctx)
	assert.Nil(t, err)

	srcBridge, err := bridge.NewBridge(common.HexToAddress(os.Getenv("SRC_BRIDGE_ADDRESS")), srcEthClient)
	assert.Nil(t, err)

	privKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("PROCESSOR_PRIVATE_KEY")))
	assert.Nil(t, err)

	from := crypto.PubkeyToAddress(privKey.PublicKey)

	opts, err := bind.NewKeyedTransactorWithChainID(privKey, srcChainID)
	assert.Nil(t, err)

	value := big.NewInt(1)

	fee := big.NewInt(1)

	opts.Value = new(big.Int).Add(value, fee)

	_, err = srcBridge.SendMessage(opts, bridge.IBridgeMessage{
		Id:          common.Big0,
		From:        from,
		SrcChainId:  srcChainID.Uint64(),
		DestChainId: destChainID.Uint64(),
		SrcOwner:    from,
		DestOwner:   from,
		To:          from,
		RefundTo:    from,
		Value:       value,
		Fee:         fee,
		GasLimit:    big.NewInt(350000),
		Data:        []byte{},
		Memo:        "",
	})

	assert.Nil(t, err)
}
