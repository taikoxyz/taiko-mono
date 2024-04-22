package bridge

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
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

	addr common.Address

	backOffRetryInterval time.Duration
	backOffMaxRetries    uint64
	ethClientTimeout     time.Duration

	wg *sync.WaitGroup

	srcChainId  *big.Int
	destChainId *big.Int

	bridgeMessageValue *big.Int
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
	b.addr = crypto.PubkeyToAddress(*publicKeyECDSA)

	b.srcChainId = srcChainID
	b.destChainId = destChainID

	b.wg = &sync.WaitGroup{}
	b.mu = &sync.Mutex{}

	b.backOffRetryInterval = time.Duration(cfg.BackoffRetryInterval) * time.Second
	b.backOffMaxRetries = cfg.BackOffMaxRetrys
	b.ethClientTimeout = time.Duration(cfg.ETHClientTimeout) * time.Second

	b.bridgeMessageValue = cfg.BridgeMessageValue

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

	_ = b.submitBridgeTx(ctx)

	return nil
}

func (b *Bridge) setLatestNonce(ctx context.Context, auth *bind.TransactOpts) error {
	pendingNonce, err := b.srcEthClient.PendingNonceAt(ctx, b.addr)
	if err != nil {
		return err
	}

	auth.Nonce = big.NewInt(int64(pendingNonce))

	return nil
}

func (b *Bridge) estimateGas(
	ctx context.Context, message bridge.IBridgeMessage) (uint64, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(b.ecdsaKey, new(big.Int).SetUint64(message.SrcChainId))
	if err != nil {
		return 0, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	// estimate gas with auth.NoSend set to true
	auth.NoSend = true
	auth.Context = ctx
	auth.GasLimit = 500000

	tx, err := b.srcBridge.SendMessage(auth, message)
	if err != nil {
		fmt.Println(err)
		return 0, errors.Wrap(err, "rcBridge.SendMessage")
	}

	gasPaddingAmt := uint64(80000)

	return tx.Gas() + gasPaddingAmt, nil
}

func (b *Bridge) submitBridgeTx(ctx context.Context) error {
	srcChainId, err := b.srcEthClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "b.srcEthClient.ChainID")
	}

	destChainId, err := b.destEthClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "b.destEthClient.ChainID")
	}

	auth, err := bind.NewKeyedTransactorWithChainID(b.ecdsaKey, new(big.Int).SetUint64(srcChainId.Uint64()))
	if err != nil {
		return errors.Wrap(err, "b.NewKeyedTransactorWithChainID")
	}

	auth.Context = ctx

	err = b.setLatestNonce(ctx, auth)
	if err != nil {
		return errors.New("b.setLatestNonce")
	}

	processingFee := big.NewInt(10000)
	value := new(big.Int)
	value.Add(b.bridgeMessageValue, processingFee)
	auth.Value = value

	message := bridge.IBridgeMessage{
		Id:          0,
		From:        b.addr,
		SrcChainId:  srcChainId.Uint64(),
		DestChainId: destChainId.Uint64(),
		SrcOwner:    b.addr,
		DestOwner:   b.addr,
		To:          b.addr,
		Value:       b.bridgeMessageValue,
		Fee:         processingFee.Uint64(),
		GasLimit:    140000,
		Data:        []byte{},
	}

	gas, err := b.estimateGas(ctx, message)
	if err != nil || gas == 0 {
		slog.Info("gas estimation failed, hardcoding gas limit", "b.estimateGas:", err)
	}

	auth.GasLimit = gas

	tx, err := b.srcBridge.SendMessage(auth, message)
	if err != nil {
		fmt.Println("b.srcBridge.SendMessage", err)
		return errors.Wrap(err, "rcBridge.SendMessage")
	}

	slog.Info("Sent tx", "txHash", hex.EncodeToString(tx.Hash().Bytes()))

	return nil
}
