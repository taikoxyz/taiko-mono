package indexer

import (
	"time"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

type Service struct {
	eventRepo eventindexer.EventRepository
	blockRepo eventindexer.BlockRepository
	statRepo  eventindexer.StatRepository
	ethClient *ethclient.Client

	processingBlockHeight uint64

	blockBatchSize      uint64
	subscriptionBackoff time.Duration

	taikol1 *taikol1.TaikoL1
	bridge  *bridge.Bridge
}

type NewServiceOpts struct {
	EventRepo           eventindexer.EventRepository
	BlockRepo           eventindexer.BlockRepository
	StatRepo            eventindexer.StatRepository
	EthClient           *ethclient.Client
	RPCClient           *rpc.Client
	SrcTaikoAddress     common.Address
	SrcBridgeAddress    common.Address
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

	bridge, err := bridge.NewBridge(opts.SrcBridgeAddress, opts.EthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewBridge")
	}

	return &Service{
		eventRepo: opts.EventRepo,
		blockRepo: opts.BlockRepo,
		statRepo:  opts.StatRepo,
		ethClient: opts.EthClient,
		taikol1:   taikoL1,
		bridge:    bridge,

		blockBatchSize:      opts.BlockBatchSize,
		subscriptionBackoff: opts.SubscriptionBackoff,
	}, nil
}
