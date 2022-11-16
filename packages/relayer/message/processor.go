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
	eventRepo     relayer.EventRepository
	srcEthClient  *ethclient.Client
	destEthClient *ethclient.Client
	rpc           *rpc.Client
	ecdsaKey      *ecdsa.PrivateKey

	destBridge       *contracts.Bridge
	destHeaderSyncer *contracts.IHeaderSync

	prover *proof.Prover

	confirmations uint64
}

type NewProcessorOpts struct {
	Prover           *proof.Prover
	ECDSAKey         *ecdsa.PrivateKey
	RPCClient        *rpc.Client
	SrcETHClient     *ethclient.Client
	DestETHClient    *ethclient.Client
	DestBridge       *contracts.Bridge
	EventRepo        relayer.EventRepository
	DestHeaderSyncer *contracts.IHeaderSync
	Confirmations    uint64
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

	if opts.SrcETHClient == nil {
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

	if opts.Confirmations == 0 {
		return nil, relayer.ErrInvalidConfirmations
	}

	return &Processor{
		eventRepo: opts.EventRepo,
		prover:    opts.Prover,
		ecdsaKey:  opts.ECDSAKey,
		rpc:       opts.RPCClient,

		srcEthClient: opts.SrcETHClient,

		destEthClient:    opts.DestETHClient,
		destBridge:       opts.DestBridge,
		destHeaderSyncer: opts.DestHeaderSyncer,

		confirmations: opts.Confirmations,
	}, nil
}
