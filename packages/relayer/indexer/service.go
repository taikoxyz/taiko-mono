package indexer

import (
	"github.com/cyberhorsey/errors"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"github.com/taikochain/taiko-mono/packages/relayer/message"
	"github.com/taikochain/taiko-mono/packages/relayer/proof"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

type Service struct {
	eventRepo     relayer.EventRepository
	blockRepo     relayer.BlockRepository
	ethClient     *ethclient.Client
	crossLayerRPC *rpc.Client

	processingBlock *relayer.Block

	bridge           *contracts.Bridge
	crossLayerBridge *contracts.Bridge

	processor *message.Processor
}

type NewServiceOpts struct {
	EventRepo               relayer.EventRepository
	BlockRepo               relayer.BlockRepository
	EthClient               *ethclient.Client
	CrossLayerEthClient     *ethclient.Client
	RPCClient               *rpc.Client
	CrossLayerRPCClient     *rpc.Client
	ECDSAKey                string
	BridgeAddress           common.Address
	CrossLayerBridgeAddress common.Address
	CrossLayerTaikoAddress  common.Address
}

func NewService(opts NewServiceOpts) (*Service, error) {
	if opts.EventRepo == nil {
		return nil, relayer.ErrNoEventRepository
	}

	if opts.BlockRepo == nil {
		return nil, relayer.ErrNoBlockRepository
	}

	if opts.EthClient == nil {
		return nil, relayer.ErrNoEthClient
	}

	if opts.ECDSAKey == "" {
		return nil, relayer.ErrNoECDSAKey
	}

	if opts.CrossLayerEthClient == nil {
		return nil, relayer.ErrNoEthClient
	}

	if opts.BridgeAddress == ZeroAddress {
		return nil, relayer.ErrNoBridgeAddress
	}

	if opts.CrossLayerBridgeAddress == ZeroAddress {
		return nil, relayer.ErrNoBridgeAddress
	}

	if opts.RPCClient == nil {
		return nil, relayer.ErrNoRPCClient
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

	prover, err := proof.New(opts.EthClient)
	if err != nil {
		return nil, errors.Wrap(err, "proof.New")
	}

	// todo: cchange this to crossLayerHeaderSyncer
	taikoL2, err := contracts.NewV1TaikoL2(opts.CrossLayerTaikoAddress, opts.CrossLayerEthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewV1TaikoL2")
	}

	processor, err := message.NewProcessor(message.NewProcessorOpts{
		Prover:              prover,
		ECDSAKey:            privateKey,
		RPCClient:           opts.RPCClient,
		CrossLayerETHClient: opts.CrossLayerEthClient,
		CrossLayerBridge:    crossLayerBridge,
		EventRepo:           opts.EventRepo,
		TaikoL2:             taikoL2,
	})
	if err != nil {
		return nil, errors.Wrap(err, "message.NewProcessor")
	}

	return &Service{
		blockRepo:     opts.BlockRepo,
		eventRepo:     opts.EventRepo,
		ethClient:     opts.EthClient,
		crossLayerRPC: opts.CrossLayerRPCClient,

		bridge:           bridge,
		crossLayerBridge: crossLayerBridge,

		processor: processor,
	}, nil
}
