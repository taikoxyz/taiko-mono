package message

import (
	"crypto/ecdsa"
	"sync"
	"testing"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"github.com/taikochain/taiko-mono/packages/relayer/mock"
	"github.com/taikochain/taiko-mono/packages/relayer/proof"
	"github.com/taikochain/taiko-mono/packages/relayer/repo"
	"gopkg.in/go-playground/assert.v1"
)

var dummyEcdsaKey = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"
var dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"

func newTestProcessor() *Processor {
	privateKey, _ := crypto.HexToECDSA(dummyEcdsaKey)

	prover, _ := proof.New(
		&mock.Blocker{},
	)

	return &Processor{
		eventRepo:        &mock.EventRepository{},
		destBridge:       &mock.Bridge{},
		srcEthClient:     &mock.EthClient{},
		destEthClient:    &mock.EthClient{},
		mu:               &sync.Mutex{},
		ecdsaKey:         privateKey,
		destHeaderSyncer: &mock.HeaderSyncer{},
		prover:           prover,
		rpc:              &mock.Caller{},
	}
}
func Test_NewProcessor(t *testing.T) {
	tests := []struct {
		name    string
		opts    NewProcessorOpts
		wantErr error
	}{
		{
			"success",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			nil,
		},
		{
			"errNoConfirmations",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
			},
			relayer.ErrInvalidConfirmations,
		},
		{
			"errNoSrcClient",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			relayer.ErrNoEthClient,
		},
		{
			"errNoProver",
			NewProcessorOpts{
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				Confirmations:    1,
				DestHeaderSyncer: &contracts.IHeaderSync{},
			},
			relayer.ErrNoProver,
		},
		{
			"errNoECDSAKey",
			NewProcessorOpts{
				Prover: &proof.Prover{},

				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			relayer.ErrNoECDSAKey,
		},
		{
			"noRpcClient",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			relayer.ErrNoRPCClient,
		},
		{
			"noDestEthClient",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			relayer.ErrNoEthClient,
		},
		{
			"errNoDestBridge",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				EventRepo:        &repo.EventRepository{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			relayer.ErrNoBridge,
		},
		{
			"errNoEventRepo",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				SrcETHClient:     &ethclient.Client{},
				DestETHClient:    &ethclient.Client{},
				DestBridge:       &contracts.Bridge{},
				DestHeaderSyncer: &contracts.IHeaderSync{},
				Confirmations:    1,
			},
			relayer.ErrNoEventRepository,
		},
		{
			"errNoTaikoL2",
			NewProcessorOpts{
				Prover:        &proof.Prover{},
				ECDSAKey:      &ecdsa.PrivateKey{},
				RPCClient:     &rpc.Client{},
				SrcETHClient:  &ethclient.Client{},
				DestETHClient: &ethclient.Client{},
				EventRepo:     &repo.EventRepository{},
				DestBridge:    &contracts.Bridge{},
				Confirmations: 1,
			},
			relayer.ErrNoTaikoL2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewProcessor(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
