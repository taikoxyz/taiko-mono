package bridge

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"sync"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

type ethClient interface {
	PendingNonceAt(ctx context.Context, account common.Address) (uint64, error)
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
	BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error)
	BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error)
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
	ChainID(ctx context.Context) (*big.Int, error)
}

type Bridge struct {
	cancel context.CancelFunc

	srcEthClient  ethClient
	destEthClient ethClient

	ecdsaKey *ecdsa.PrivateKey

	srcBridge  relayer.Bridge
	destBridge relayer.Bridge

	mu *sync.Mutex

	destNonce  uint64
	bridgeAddr common.Address

	confirmations uint64

	confTimeoutInSeconds int64

	backOffRetryInterval time.Duration
	backOffMaxRetries    uint64
	ethClientTimeout     time.Duration

	wg *sync.WaitGroup

	srcChainId  *big.Int
	destChainId *big.Int
}

func (b *Bridge) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, b, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, b *Bridge, cfg *Config) error {

	srcEthClient, err := ethclient.Dial(cfg.SrcRPCUrl)
	if err != nil {
		return err
	}

	destEthClient, err := ethclient.Dial(cfg.DestRPCUrl)
	if err != nil {
		return err
	}

	srcBridge, err := bridge.NewBridge(cfg.SrcBridgeAddress, srcEthClient)
	if err != nil {
		return err
	}

	destBridge, err := bridge.NewBridge(cfg.DestBridgeAddress, destEthClient)
	if err != nil {
		return err
	}

	srcChainID, err := srcEthClient.ChainID(context.Background())
	if err != nil {
		return err
	}

	destChainID, err := destEthClient.ChainID(context.Background())
	if err != nil {
		return err
	}

	publicKey := cfg.BridgePrivateKey.Public()

	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return errors.New("unable to convert public key")
	}

	b.srcEthClient = srcEthClient
	b.destEthClient = destEthClient

	b.destBridge = destBridge
	b.srcBridge = srcBridge

	b.ecdsaKey = cfg.BridgePrivateKey
	b.bridgeAddr = crypto.PubkeyToAddress(*publicKeyECDSA)

	b.srcChainId = srcChainID
	b.destChainId = destChainID

	b.confTimeoutInSeconds = int64(cfg.ConfirmationsTimeout)
	b.confirmations = cfg.Confirmations

	b.wg = &sync.WaitGroup{}
	b.mu = &sync.Mutex{}

	b.backOffRetryInterval = time.Duration(cfg.BackoffRetryInterval) * time.Second
	b.backOffMaxRetries = cfg.BackOffMaxRetrys
	b.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	return nil
}

func (b *Bridge) Name() string {
	return "bridge"
}

func (b *Bridge) Close(ctx context.Context) {
	b.cancel()

	b.wg.Wait()
}

func (b *Bridge) Start() error {
	slog.Info("Start bridge")

	ctx, cancel := context.WithCancel(context.Background())

	b.cancel = cancel

	b.submitBridge(ctx)

	return nil
}

func (b *Bridge) submitBridge(ctx context.Context) error {
	slog.Info("Submit bridge")
	// bridge-ui/src/libs/bridge/ETHBridge.ts

	return nil
}
