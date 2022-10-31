package indexer

import (
	"crypto/ecdsa"

	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/ethclient/gethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

var (
	ErrNoEthClient     = errors.Validation.NewWithKeyAndDetail("ERR_NO_ETH_CLIENT", "EthClient is required")
	ErrNoECDSAKey      = errors.Validation.NewWithKeyAndDetail("ERR_NO_ECDSA_KEY", "ECDSAKey is required")
	ErrNoBridgeAddress = errors.Validation.NewWithKeyAndDetail("ERR_NO_BRIDGE_ADDRESS", "BridgeAddress is required")
)

type Service struct {
	eventRepo           relayer.EventRepository
	blockRepo           relayer.BlockRepository
	ethClient           *ethclient.Client
	crossLayerEthClient *ethclient.Client
	gethClient          *gethclient.Client
	ecdsaKey            *ecdsa.PrivateKey

	processingBlock *relayer.Block

	bridge           *contracts.Bridge
	crossLayerBridge *contracts.Bridge

	bridgeAddress           common.Address
	crossLayerBridgeAddress common.Address
}

type NewServiceOpts struct {
	EventRepo               relayer.EventRepository
	BlockRepo               relayer.BlockRepository
	EthClient               *ethclient.Client
	CrossLayerEthClient     *ethclient.Client
	GethClient              *gethclient.Client
	ECDSAKey                string
	BridgeAddress           common.Address
	CrossLayerBridgeAddress common.Address
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

	if opts.ECDSAKey == "" {
		return nil, ErrNoECDSAKey
	}

	if opts.CrossLayerEthClient == nil {
		return nil, ErrNoEthClient
	}

	if opts.BridgeAddress == common.HexToAddress("0x0000000000000000000000000000000000000000") {
		return nil, ErrNoBridgeAddress
	}

	if opts.CrossLayerBridgeAddress == common.HexToAddress("0x0000000000000000000000000000000000000000") {
		return nil, ErrNoBridgeAddress
	}

	privateKey, err := crypto.HexToECDSA(opts.ECDSAKey)
	if err != nil {
		return nil, errors.Wrap(err, "crypto.HexToECDSA")
	}

	bridge, err := contracts.NewBridge(opts.BridgeAddress, opts.EthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewBridge")
	}

	crossLayerBridge, err := contracts.NewBridge(opts.CrossLayerBridgeAddress, opts.CrossLayerEthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewBridge")
	}

	return &Service{
		blockRepo:           opts.BlockRepo,
		crossLayerEthClient: opts.CrossLayerEthClient,
		eventRepo:           opts.EventRepo,
		ethClient:           opts.EthClient,
		gethClient:          opts.GethClient,
		ecdsaKey:            privateKey,

		bridge:           bridge,
		crossLayerBridge: crossLayerBridge,

		bridgeAddress:           opts.BridgeAddress,
		crossLayerBridgeAddress: opts.CrossLayerBridgeAddress,
	}, nil
}
