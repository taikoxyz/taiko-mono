package message

import (
	"context"
	"crypto/ecdsa"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/proof"
)

type ethClient interface {
	PendingNonceAt(ctx context.Context, account common.Address) (uint64, error)
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
}
type Processor struct {
	eventRepo     relayer.EventRepository
	srcEthClient  ethClient
	destEthClient ethClient
	rpc           relayer.Caller
	ecdsaKey      *ecdsa.PrivateKey

	destBridge       relayer.Bridge
	destHeaderSyncer relayer.HeaderSyncer

	prover *proof.Prover

	mu *sync.Mutex

	destNonce               uint64
	relayerAddr             common.Address
	srcSignalServiceAddress common.Address
	confirmations           uint64

	profitableOnly            relayer.ProfitableOnly
	headerSyncIntervalSeconds int64
}

type NewProcessorOpts struct {
	Prover                    *proof.Prover
	ECDSAKey                  *ecdsa.PrivateKey
	RPCClient                 relayer.Caller
	SrcETHClient              ethClient
	DestETHClient             ethClient
	DestBridge                relayer.Bridge
	EventRepo                 relayer.EventRepository
	DestHeaderSyncer          relayer.HeaderSyncer
	RelayerAddress            common.Address
	SrcSignalServiceAddress   common.Address
	Confirmations             uint64
	ProfitableOnly            relayer.ProfitableOnly
	HeaderSyncIntervalSeconds int64
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

		mu: &sync.Mutex{},

		destNonce:               0,
		relayerAddr:             opts.RelayerAddress,
		srcSignalServiceAddress: opts.SrcSignalServiceAddress,
		confirmations:           opts.Confirmations,

		profitableOnly:            opts.ProfitableOnly,
		headerSyncIntervalSeconds: opts.HeaderSyncIntervalSeconds,
	}, nil
}
