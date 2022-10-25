package indexer

import (
	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

var (
	ErrNoEthClient = errors.Validation.NewWithKeyAndDetail("ERR_NO_ETH_CLIENT", "EthClient is required")
)

type Service struct {
	eventRepo relayer.EventRepository
	blockRepo relayer.BlockRepository
	ethClient *ethclient.Client
}

type NewServiceOpts struct {
	EventRepo relayer.EventRepository
	BlockRepo relayer.BlockRepository
	EthClient *ethclient.Client
}

func NewService(opts NewServiceOpts) (*Service, error) {
	if opts.EventRepo == nil {
		return nil, relayer.ErrNoEventRepository
	}

	if opts.BlockRepo == nil {
		return nil, relayer.ErrNoBlockRepository
	}

	if opts.EthClient == nil {
		return nil, ErrNoEthClient
	}

	return &Service{
		blockRepo: opts.BlockRepo,
		eventRepo: opts.EventRepo,
		ethClient: opts.EthClient,
	}, nil
}
