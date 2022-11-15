package indexer

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/mock"
	"github.com/taikochain/taiko-mono/packages/relayer/repo"
	"gopkg.in/go-playground/assert.v1"
)

var dummyEcdsaKey = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"
var dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"

func newTestService() *Service {
	return &Service{
		blockRepo: &mock.BlockRepository{},
		ethClient: &mock.EthClient{},

		processingBlock: &relayer.Block{},
	}
}

func Test_NewService(t *testing.T) {
	tests := []struct {
		name    string
		opts    NewServiceOpts
		wantErr error
	}{
		{
			"success",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				RPCClient:         &rpc.Client{},
				EthClient:         &ethclient.Client{},
				DestEthClient:     &ethclient.Client{},
				ECDSAKey:          dummyEcdsaKey,
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			nil,
		},
		{
			"noRpcClien",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				EthClient:         &ethclient.Client{},
				DestEthClient:     &ethclient.Client{},
				ECDSAKey:          dummyEcdsaKey,
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoRPCClient,
		},
		{
			"noBridgeAddress",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				EthClient:         &ethclient.Client{},
				DestEthClient:     &ethclient.Client{},
				ECDSAKey:          dummyEcdsaKey,
				RPCClient:         &rpc.Client{},
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoBridgeAddress,
		},
		{
			"noDestBridgeAddress",
			NewServiceOpts{
				EventRepo:     &repo.EventRepository{},
				BlockRepo:     &repo.BlockRepository{},
				EthClient:     &ethclient.Client{},
				DestEthClient: &ethclient.Client{},
				ECDSAKey:      dummyEcdsaKey,
				RPCClient:     &rpc.Client{},
				BridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoBridgeAddress,
		},
		{
			"noECDSAKey",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				RPCClient:         &rpc.Client{},
				EthClient:         &ethclient.Client{},
				DestEthClient:     &ethclient.Client{},
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoECDSAKey,
		},
		{
			"noEventRepo",
			NewServiceOpts{
				BlockRepo:         &repo.BlockRepository{},
				EthClient:         &ethclient.Client{},
				ECDSAKey:          dummyEcdsaKey,
				DestEthClient:     &ethclient.Client{},
				BridgeAddress:     common.HexToAddress(dummyAddress),
				RPCClient:         &rpc.Client{},
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoEventRepository,
		},
		{
			"noBlockRepo",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				EthClient:         &ethclient.Client{},
				ECDSAKey:          dummyEcdsaKey,
				RPCClient:         &rpc.Client{},
				DestEthClient:     &ethclient.Client{},
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoBlockRepository,
		},
		{
			"noEthClient",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				ECDSAKey:          dummyEcdsaKey,
				RPCClient:         &rpc.Client{},
				DestEthClient:     &ethclient.Client{},
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoEthClient,
		},
		{
			"noDestEthClient",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				ECDSAKey:          dummyEcdsaKey,
				EthClient:         &ethclient.Client{},
				RPCClient:         &rpc.Client{},
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
			},
			relayer.ErrNoEthClient,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewService(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
