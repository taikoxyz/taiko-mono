package message

import (
	"crypto/ecdsa"
	"testing"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"github.com/taikochain/taiko-mono/packages/relayer/proof"
	"github.com/taikochain/taiko-mono/packages/relayer/repo"
	"gopkg.in/go-playground/assert.v1"
)

func Test_NewProcessor(t *testing.T) {
	tests := []struct {
		name    string
		opts    NewProcessorOpts
		wantErr error
	}{
		{
			"success",
			NewProcessorOpts{
				Prover:              &proof.Prover{},
				ECDSAKey:            &ecdsa.PrivateKey{},
				RPCClient:           &rpc.Client{},
				CrossLayerETHClient: &ethclient.Client{},
				CrossLayerBridge:    &contracts.Bridge{},
				EventRepo:           &repo.EventRepository{},
				TaikoL2:             &contracts.V1TaikoL2{},
			},
			nil,
		},
		{
			"errNoProver",
			NewProcessorOpts{
				ECDSAKey:            &ecdsa.PrivateKey{},
				RPCClient:           &rpc.Client{},
				CrossLayerETHClient: &ethclient.Client{},
				CrossLayerBridge:    &contracts.Bridge{},
				EventRepo:           &repo.EventRepository{},
				TaikoL2:             &contracts.V1TaikoL2{},
			},
			relayer.ErrNoProver,
		},
		{
			"errNoECDSAKey",
			NewProcessorOpts{
				Prover: &proof.Prover{},

				RPCClient:           &rpc.Client{},
				CrossLayerETHClient: &ethclient.Client{},
				CrossLayerBridge:    &contracts.Bridge{},
				EventRepo:           &repo.EventRepository{},
				TaikoL2:             &contracts.V1TaikoL2{},
			},
			relayer.ErrNoECDSAKey,
		},
		{
			"noRpcClient",
			NewProcessorOpts{
				Prover:              &proof.Prover{},
				ECDSAKey:            &ecdsa.PrivateKey{},
				CrossLayerETHClient: &ethclient.Client{},
				CrossLayerBridge:    &contracts.Bridge{},
				EventRepo:           &repo.EventRepository{},
				TaikoL2:             &contracts.V1TaikoL2{},
			},
			relayer.ErrNoRPCClient,
		},
		{
			"noCrossLayerEthClient",
			NewProcessorOpts{
				Prover:           &proof.Prover{},
				ECDSAKey:         &ecdsa.PrivateKey{},
				RPCClient:        &rpc.Client{},
				CrossLayerBridge: &contracts.Bridge{},
				EventRepo:        &repo.EventRepository{},
				TaikoL2:          &contracts.V1TaikoL2{},
			},
			relayer.ErrNoEthClient,
		},
		{
			"errNoCrossLayerBridge",
			NewProcessorOpts{
				Prover:              &proof.Prover{},
				ECDSAKey:            &ecdsa.PrivateKey{},
				RPCClient:           &rpc.Client{},
				CrossLayerETHClient: &ethclient.Client{},
				EventRepo:           &repo.EventRepository{},
				TaikoL2:             &contracts.V1TaikoL2{},
			},
			relayer.ErrNoBridge,
		},
		{
			"errNoEventRepo",
			NewProcessorOpts{
				Prover:              &proof.Prover{},
				ECDSAKey:            &ecdsa.PrivateKey{},
				RPCClient:           &rpc.Client{},
				CrossLayerETHClient: &ethclient.Client{},
				CrossLayerBridge:    &contracts.Bridge{},
				TaikoL2:             &contracts.V1TaikoL2{},
			},
			relayer.ErrNoEventRepository,
		},
		{
			"errNoTaikoL2",
			NewProcessorOpts{
				Prover:              &proof.Prover{},
				ECDSAKey:            &ecdsa.PrivateKey{},
				RPCClient:           &rpc.Client{},
				CrossLayerETHClient: &ethclient.Client{},
				EventRepo:           &repo.EventRepository{},
				CrossLayerBridge:    &contracts.Bridge{},
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
