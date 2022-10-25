package indexer

import (
	"crypto/ecdsa"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/ethclient/gethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

var (
	ErrNoEthClient = errors.Validation.NewWithKeyAndDetail("ERR_NO_ETH_CLIENT", "EthClient is required")
)

type Service struct {
	eventRepo           relayer.EventRepository
	blockRepo           relayer.BlockRepository
	ethClient           *ethclient.Client
	crossLayerEthClient *ethclient.Client
	gethClient          *gethclient.Client
	ecdsaKey            *ecdsa.PrivateKey
}

type NewServiceOpts struct {
	EventRepo           relayer.EventRepository
	BlockRepo           relayer.BlockRepository
	EthClient           *ethclient.Client
	CrossLayerEthClient *ethclient.Client
	GethClient          *gethclient.Client
	ECDSAKey            string
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

	privateKey, err := crypto.HexToECDSA(opts.ECDSAKey)
	if err != nil {
		return nil, errors.Wrap(err, "crypto.HexToECDSA")
	}

	if err != nil {
		return nil, err
	}
	return &Service{
		blockRepo:           opts.BlockRepo,
		crossLayerEthClient: opts.CrossLayerEthClient,
		eventRepo:           opts.EventRepo,
		ethClient:           opts.EthClient,
		gethClient:          opts.GethClient,
		ecdsaKey:            privateKey,
	}, nil
}
