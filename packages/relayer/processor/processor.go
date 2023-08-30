package processor

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"log/slog"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/pkg/errors"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc1155vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc20vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc721vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/icrosschainsync"
	"github.com/taikoxyz/taiko-mono/packages/relayer/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
)

type ethClient interface {
	PendingNonceAt(ctx context.Context, account common.Address) (uint64, error)
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
	ChainID(ctx context.Context) (*big.Int, error)
}

type Processor struct {
	eventRepo relayer.EventRepository

	queue queue.Queue

	srcEthClient  ethClient
	destEthClient ethClient
	rpc           relayer.Caller

	ecdsaKey *ecdsa.PrivateKey

	destBridge       relayer.Bridge
	destHeaderSyncer relayer.HeaderSyncer
	destERC20Vault   relayer.TokenVault
	destERC1155Vault relayer.TokenVault
	destERC721Vault  relayer.TokenVault

	prover *proof.Prover

	mu *sync.Mutex

	destNonce               uint64
	relayerAddr             common.Address
	srcSignalServiceAddress common.Address
	confirmations           uint64

	profitableOnly            relayer.ProfitableOnly
	headerSyncIntervalSeconds int64

	confTimeoutInSeconds int64

	msgCh chan queue.Message

	wg *sync.WaitGroup

	srcChainId *big.Int
}

type NewProcessorOpts struct {
	Prover                        *proof.Prover
	ECDSAKey                      string
	RPCClient                     relayer.Caller
	SrcETHClient                  ethClient
	DestETHClient                 ethClient
	EventRepo                     relayer.EventRepository
	Queue                         queue.Queue
	DestBridgeAddress             common.Address
	DestTaikoAddress              common.Address
	DestERC20VaultAddress         common.Address
	DestERC721VaultAddress        common.Address
	DestERC1155VaultAddress       common.Address
	SrcSignalServiceAddress       common.Address
	Confirmations                 uint64
	ProfitableOnly                relayer.ProfitableOnly
	HeaderSyncIntervalInSeconds   int64
	ConfirmationsTimeoutInSeconds int64
}

func NewProcessor(opts NewProcessorOpts) (*Processor, error) {
	if opts.Prover == nil {
		return nil, relayer.ErrNoProver
	}

	if opts.ECDSAKey == "" {
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

	if opts.EventRepo == nil {
		return nil, relayer.ErrNoEventRepository
	}

	if opts.Confirmations == 0 {
		return nil, relayer.ErrInvalidConfirmations
	}

	if opts.ConfirmationsTimeoutInSeconds == 0 {
		return nil, relayer.ErrInvalidConfirmationsTimeoutInSeconds
	}

	destHeaderSyncer, err := icrosschainsync.NewICrossChainSync(
		opts.DestTaikoAddress,
		opts.DestETHClient.(*ethclient.Client),
	)
	if err != nil {
		return nil, errors.Wrap(err, "icrosschainsync.NewTaikoL2")
	}

	destERC20Vault, err := erc20vault.NewERC20Vault(opts.DestERC20VaultAddress, opts.DestETHClient.(*ethclient.Client))
	if err != nil {
		return nil, errors.Wrap(err, "erc20vault.NewERC20Vault")
	}

	var destERC721Vault *erc721vault.ERC721Vault
	if opts.DestERC721VaultAddress.Hex() != relayer.ZeroAddress.Hex() {
		destERC721Vault, err = erc721vault.NewERC721Vault(opts.DestERC721VaultAddress, opts.DestETHClient.(*ethclient.Client))
		if err != nil {
			return nil, errors.Wrap(err, "erc721vault.NewERC721Vault")
		}
	}

	var destERC1155Vault *erc1155vault.ERC1155Vault
	if opts.DestERC1155VaultAddress.Hex() != relayer.ZeroAddress.Hex() {
		destERC1155Vault, err = erc1155vault.NewERC1155Vault(
			opts.DestERC1155VaultAddress,
			opts.DestETHClient.(*ethclient.Client),
		)
		if err != nil {
			return nil, errors.Wrap(err, "erc1155vault.NewERC1155Vault")
		}
	}

	destBridge, err := bridge.NewBridge(opts.DestBridgeAddress, opts.DestETHClient.(*ethclient.Client))
	if err != nil {
		return nil, errors.Wrap(err, "bridge.NewBridge")
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

	srcChainId, err := opts.SrcETHClient.ChainID(context.Background())
	if err != nil {
		return nil, errors.Wrap(err, "opts.SrcETHClient.ChainID")
	}

	return &Processor{
		eventRepo: opts.EventRepo,
		prover:    opts.Prover,
		ecdsaKey:  privateKey,
		rpc:       opts.RPCClient,

		srcEthClient: opts.SrcETHClient,

		destEthClient:    opts.DestETHClient,
		destBridge:       destBridge,
		destHeaderSyncer: destHeaderSyncer,
		destERC20Vault:   destERC20Vault,
		destERC721Vault:  destERC1155Vault,
		destERC1155Vault: destERC721Vault,

		mu: &sync.Mutex{},

		destNonce:               0,
		relayerAddr:             relayerAddr,
		srcSignalServiceAddress: opts.SrcSignalServiceAddress,
		confirmations:           opts.Confirmations,

		profitableOnly:            opts.ProfitableOnly,
		headerSyncIntervalSeconds: opts.HeaderSyncIntervalInSeconds,
		confTimeoutInSeconds:      opts.ConfirmationsTimeoutInSeconds,

		queue: opts.Queue,
		msgCh: make(chan queue.Message),
		wg:    &sync.WaitGroup{},

		srcChainId: srcChainId,
	}, nil
}

func (p *Processor) Start(ctx context.Context) error {
	if err := p.queue.Start(ctx, p.queueName()); err != nil {
		return err
	}

	if err := p.queue.Subscribe(ctx, p.msgCh); err != nil {
		return err
	}

	p.wg.Add(1)
	go p.eventLoop(ctx)

	return nil
}

func (p *Processor) queueName() string {
	return fmt.Sprintf("%v-queue", p.srcChainId.String())
}

func (p *Processor) eventLoop(ctx context.Context) {
	defer func() {
		p.wg.Done()
	}()

	for {
		select {
		case <-ctx.Done():
			return
		case msg := <-p.msgCh:
			if err := p.processMessage(ctx, msg); err != nil {
				slog.Error("err processing message", "msg", msg)
			}
		}
	}
}
