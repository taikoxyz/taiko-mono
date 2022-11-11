package message

import (
	"crypto/ecdsa"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rpc"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"github.com/taikochain/taiko-mono/packages/relayer/proof"
)

type Processor struct {
	eventRepo     relayer.EventRepository
	destEthClient *ethclient.Client
	rpc           *rpc.Client
	ecdsaKey      *ecdsa.PrivateKey

	destBridge       *contracts.Bridge
	destHeaderSyncer *contracts.IHeaderSync

	prover *proof.Prover

	mu *sync.Mutex

	destNonce   uint64
	relayerAddr common.Address
}

type NewProcessorOpts struct {
	Prover           *proof.Prover
	ECDSAKey         *ecdsa.PrivateKey
	RPCClient        *rpc.Client
	DestETHClient    *ethclient.Client
	DestBridge       *contracts.Bridge
	EventRepo        relayer.EventRepository
	DestHeaderSyncer *contracts.IHeaderSync
	RelayerAddress   common.Address
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

	if opts.DestETHClient == nil {
		return nil, relayer.ErrNoEthClient
	}

	if opts.DestBridge == nil {
		return nil, relayer.ErrNoBridge
	}

	if opts.EventRepo == nil {
		return nil, relayer.ErrNoEventRepository
	}

	if opts.DestHeaderSyncer == nil {
		return nil, relayer.ErrNoTaikoL2
	}

	return &Processor{
		eventRepo:        opts.EventRepo,
		prover:           opts.Prover,
		ecdsaKey:         opts.ECDSAKey,
		rpc:              opts.RPCClient,
		destEthClient:    opts.DestETHClient,
		destBridge:       opts.DestBridge,
		destHeaderSyncer: opts.DestHeaderSyncer,

		mu: &sync.Mutex{},

		destNonce:   0,
		relayerAddr: opts.RelayerAddress,
	}, nil
}
