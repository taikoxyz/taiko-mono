package indexer

import (
	"context"
	"math/big"
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

type ethClient interface {
	ChainID(ctx context.Context) (*big.Int, error)
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
	SubscribeNewHead(ctx context.Context, ch chan<- *types.Header) (ethereum.Subscription, error)
}

type Indexer struct {
	eventRepo relayer.EventRepository
	blockRepo relayer.BlockRepository
	ethClient ethClient

	processingBlockHeight uint64

	bridge     relayer.Bridge
	destBridge relayer.Bridge

	blockBatchSize      uint64
	numGoroutines       int
	subscriptionBackoff time.Duration

	taikol1 *taikol1.TaikoL1

	queue queue.Queue

	srcChainId *big.Int
}

type NewIndexerOpts struct {
	EventRepo           relayer.EventRepository
	BlockRepo           relayer.BlockRepository
	Queue               queue.Queue
	EthClient           ethClient
	DestEthClient       ethClient
	RPCClient           *rpc.Client
	BridgeAddress       common.Address
	DestBridgeAddress   common.Address
	SrcTaikoAddress     common.Address
	BlockBatchSize      uint64
	NumGoroutines       int
	SubscriptionBackoff time.Duration
}

func NewIndexer(opts NewIndexerOpts) (*Indexer, error) {
	if opts.EventRepo == nil {
		return nil, relayer.ErrNoEventRepository
	}

	if opts.BlockRepo == nil {
		return nil, relayer.ErrNoBlockRepository
	}

	if opts.EthClient == nil {
		return nil, relayer.ErrNoEthClient
	}

	if opts.DestEthClient == nil {
		return nil, relayer.ErrNoEthClient
	}

	if opts.BridgeAddress == ZeroAddress {
		return nil, relayer.ErrNoBridgeAddress
	}

	if opts.DestBridgeAddress == ZeroAddress {
		return nil, relayer.ErrNoBridgeAddress
	}

	if opts.RPCClient == nil {
		return nil, relayer.ErrNoRPCClient
	}

	srcBridge, err := bridge.NewBridge(opts.BridgeAddress, opts.EthClient.(*ethclient.Client))
	if err != nil {
		return nil, errors.Wrap(err, "bridge.NewBridge")
	}

	destBridge, err := bridge.NewBridge(opts.DestBridgeAddress, opts.DestEthClient.(*ethclient.Client))
	if err != nil {
		return nil, errors.Wrap(err, "bridge.NewBridge")
	}

	var taikoL1 *taikol1.TaikoL1
	if opts.SrcTaikoAddress != ZeroAddress {
		taikoL1, err = taikol1.NewTaikoL1(opts.SrcTaikoAddress, opts.EthClient.(*ethclient.Client))
		if err != nil {
			return nil, errors.Wrap(err, "taikol1.NewTaikoL1")
		}
	}

	chainID, err := opts.EthClient.ChainID(context.Background())
	if err != nil {
		return nil, errors.Wrap(err, "opts.EthClient.ChainID")
	}

	return &Indexer{
		blockRepo: opts.BlockRepo,
		eventRepo: opts.EventRepo,
		ethClient: opts.EthClient,

		bridge:     srcBridge,
		destBridge: destBridge,
		taikol1:    taikoL1,

		blockBatchSize:      opts.BlockBatchSize,
		numGoroutines:       opts.NumGoroutines,
		subscriptionBackoff: opts.SubscriptionBackoff,

		queue: opts.Queue,

		srcChainId: chainID,
	}, nil
}
