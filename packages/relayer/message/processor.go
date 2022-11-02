package message

import (
	"crypto/ecdsa"

	"github.com/ethereum/go-ethereum/rpc"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"github.com/taikochain/taiko-mono/packages/relayer/proof"
)

type Processor struct {
	eventRepo           relayer.EventRepository
	crossLayerEthClient *ethclient.Client
	rpc                 *rpc.Client
	ecdsaKey            *ecdsa.PrivateKey

	crossLayerBridge *contracts.Bridge
	taikoL2          *contracts.V1TaikoL2

	prover *proof.Prover
}

type NewProcessorOpts struct {
	Prover              *proof.Prover
	ECDSAKey            *ecdsa.PrivateKey
	RPCClient           *rpc.Client
	CrossLayerETHClient *ethclient.Client
	CrossLayerBridge    *contracts.Bridge
	EventRepo           relayer.EventRepository
	TaikoL2             *contracts.V1TaikoL2
}

func NewProcessor(opts NewProcessorOpts) (*Processor, error) {
	if opts.Prover == nil {
		return nil, relayer.ErrNoProver
	}
	if opts.ECDSAKey == nil {
		return nil, relayer.ErrNoECDSAKey
	}
	if opts.RPCClient == nil {
		return nil, relayer.ErrNoRPCClient
	}
	if opts.CrossLayerETHClient == nil {
		return nil, relayer.ErrNoEthClient
	}
	if opts.CrossLayerBridge == nil {
		return nil, relayer.ErrNoBridge
	}
	if opts.EventRepo == nil {
		return nil, relayer.ErrNoEventRepository
	}
	if opts.TaikoL2 == nil {
		return nil, relayer.ErrNoTaikoL2
	}
	return &Processor{
		eventRepo:           opts.EventRepo,
		prover:              opts.Prover,
		ecdsaKey:            opts.ECDSAKey,
		rpc:                 opts.RPCClient,
		crossLayerEthClient: opts.CrossLayerETHClient,
		crossLayerBridge:    opts.CrossLayerBridge,
		taikoL2:             opts.TaikoL2,
	}, nil
}
