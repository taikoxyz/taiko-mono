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
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

type ethClient interface {
	ChainID(ctx context.Context) (*big.Int, error)
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
	SubscribeNewHead(ctx context.Context, ch chan<- *types.Header) (ethereum.Subscription, error)
}

type Service struct {
	eventRepo eventindexer.EventRepository
	blockRepo eventindexer.BlockRepository
	ethClient ethClient

	processingBlockHeight uint64

	blockBatchSize      uint64
	subscriptionBackoff time.Duration

	taikol1 *taikol1.TaikoL1
}

type NewServiceOpts struct {
	EventRepo           eventindexer.EventRepository
	BlockRepo           eventindexer.BlockRepository
	EthClient           *ethclient.Client
	RPCClient           *rpc.Client
	SrcTaikoAddress     common.Address
	BlockBatchSize      uint64
	SubscriptionBackoff time.Duration
}

func NewService(opts NewServiceOpts) (*Service, error) {
	if opts.EventRepo == nil {
		return nil, eventindexer.ErrNoEventRepository
	}

	if opts.EthClient == nil {
		return nil, eventindexer.ErrNoEthClient
	}

	if opts.RPCClient == nil {
		return nil, eventindexer.ErrNoRPCClient
	}

	taikoL1, err := taikol1.NewTaikoL1(opts.SrcTaikoAddress, opts.EthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewTaikoL1")
	}

	return &Service{
		eventRepo: opts.EventRepo,
		blockRepo: opts.BlockRepo,
		ethClient: opts.EthClient,
		taikol1:   taikoL1,

		blockBatchSize:      opts.BlockBatchSize,
		subscriptionBackoff: opts.SubscriptionBackoff,
	}, nil
}
