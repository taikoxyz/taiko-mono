package indexer

import (
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

type Service struct {
	eventRepo     eventindexer.EventRepository
	blockRepo     eventindexer.BlockRepository
	statRepo      eventindexer.StatRepository
	ethClient     *ethclient.Client
	destEthClient *ethclient.Client

	processingBlockHeight uint64

	blockBatchSize      uint64
	subscriptionBackoff time.Duration

	taikol1 *taikol1.TaikoL1
}

type NewServiceOpts struct {
	EventRepo           eventindexer.EventRepository
	BlockRepo           eventindexer.BlockRepository
	StatRepo            eventindexer.StatRepository
	EthClient           *ethclient.Client
	DestEthClient       *ethclient.Client
	RPCClient           *rpc.Client
	SrcTaikoAddress     common.Address
	BlockBatchSize      uint64
	SubscriptionBackoff time.Duration
}

func NewService(opts NewServiceOpts) (*Service, error) {
	if opts.EventRepo == nil {
		return nil, eventindexer.ErrNoEventRepository
	}

	if opts.EthClient == nil || opts.DestEthClient == nil {
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
		eventRepo:     opts.EventRepo,
		blockRepo:     opts.BlockRepo,
		statRepo:      opts.StatRepo,
		ethClient:     opts.EthClient,
		destEthClient: opts.DestEthClient,
		taikol1:       taikoL1,

		blockBatchSize:      opts.BlockBatchSize,
		subscriptionBackoff: opts.SubscriptionBackoff,
	}, nil
}
