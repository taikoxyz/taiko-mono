package indexer

import (
	"crypto/ecdsa"

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
	eventRepo relayer.EventRepository
	blockRepo relayer.BlockRepository
	ethClient *ethclient.Client
	destRPC   *rpc.Client

	processingBlock *relayer.Block

	bridge     *contracts.Bridge
	destBridge *contracts.Bridge

	processor *message.Processor

	relayerAddr common.Address

	errChan chan error

	blockBatchSize uint64
}

type NewServiceOpts struct {
	EventRepo         relayer.EventRepository
	BlockRepo         relayer.BlockRepository
	EthClient         *ethclient.Client
	DestEthClient     *ethclient.Client
	RPCClient         *rpc.Client
	DestRPCClient     *rpc.Client
	ECDSAKey          string
	BridgeAddress     common.Address
	DestBridgeAddress common.Address
	DestTaikoAddress  common.Address
	BlockBatchSize    uint64
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

	privateKey, err := crypto.HexToECDSA(opts.ECDSAKey)
	if err != nil {
		return nil, errors.Wrap(err, "crypto.HexToECDSA")
	}

	publicKey := privateKey.Public()

	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.Wrap(err, "publicKey.(*ecdsa.PublicKey)")
	}

	relayerAddr := crypto.PubkeyToAddress(*publicKeyECDSA)

	bridge, err := contracts.NewBridge(opts.BridgeAddress, opts.EthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewBridge")
	}

	destBridge, err := contracts.NewBridge(opts.DestBridgeAddress, opts.DestEthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewBridge")
	}

	prover, err := proof.New(opts.EthClient)
	if err != nil {
		return nil, errors.Wrap(err, "proof.New")
	}

	destHeaderSyncer, err := contracts.NewIHeaderSync(opts.DestTaikoAddress, opts.DestEthClient)
	if err != nil {
		return nil, errors.Wrap(err, "contracts.NewV1TaikoL2")
	}

	processor, err := message.NewProcessor(message.NewProcessorOpts{
		Prover:           prover,
		ECDSAKey:         privateKey,
		RPCClient:        opts.RPCClient,
		DestETHClient:    opts.DestEthClient,
		DestBridge:       destBridge,
		EventRepo:        opts.EventRepo,
		DestHeaderSyncer: destHeaderSyncer,
		RelayerAddress:   relayerAddr,
	})
	if err != nil {
		return nil, errors.Wrap(err, "message.NewProcessor")
	}

	return &Service{
		blockRepo: opts.BlockRepo,
		eventRepo: opts.EventRepo,
		ethClient: opts.EthClient,
		destRPC:   opts.DestRPCClient,

		bridge:     bridge,
		destBridge: destBridge,

		processor: processor,

		relayerAddr: relayerAddr,

		errChan: make(chan error),

		blockBatchSize: opts.BlockBatchSize,
	}, nil
}
