package indexer

import (
	"errors"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/message"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/repo"
)

var dummyEcdsaKey = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"
var dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"

func newTestService() (*Service, relayer.Bridge) {
	b := &mock.Bridge{}

	privateKey, _ := crypto.HexToECDSA(dummyEcdsaKey)

	prover, _ := proof.New(
		&mock.Blocker{},
	)

	processor, _ := message.NewProcessor(message.NewProcessorOpts{
		EventRepo:        &mock.EventRepository{},
		DestBridge:       &mock.Bridge{},
		SrcETHClient:     &mock.EthClient{},
		DestETHClient:    &mock.EthClient{},
		ECDSAKey:         privateKey,
		DestHeaderSyncer: &mock.HeaderSyncer{},
		Prover:           prover,
		RPCClient:        &mock.Caller{},
	})

	return &Service{
		blockRepo:     &mock.BlockRepository{},
		eventRepo:     &mock.EventRepository{},
		bridge:        b,
		destBridge:    b,
		ethClient:     &mock.EthClient{},
		numGoroutines: 10,

		processingBlockHeight: 0,
		processor:             processor,
		blockBatchSize:        100,
	}, b
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
				Confirmations:     1,
			},
			nil,
		},
		{
			"invalidECDSAKey",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				RPCClient:         &rpc.Client{},
				EthClient:         &ethclient.Client{},
				DestEthClient:     &ethclient.Client{},
				ECDSAKey:          ">>>",
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
				Confirmations:     1,
			},
			errors.New("crypto.HexToECDSA: invalid hex character '>' in private key"),
		},
		{
			"noRpcClient",
			NewServiceOpts{
				EventRepo:         &repo.EventRepository{},
				BlockRepo:         &repo.BlockRepository{},
				EthClient:         &ethclient.Client{},
				DestEthClient:     &ethclient.Client{},
				ECDSAKey:          dummyEcdsaKey,
				BridgeAddress:     common.HexToAddress(dummyAddress),
				DestBridgeAddress: common.HexToAddress(dummyAddress),
				Confirmations:     1,
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
				Confirmations:     1,
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
				Confirmations: 1,
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
				Confirmations:     1,
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
				Confirmations:     1,
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
				Confirmations:     1,
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
				Confirmations:     1,
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
				Confirmations:     1,
			},
			relayer.ErrNoEthClient,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewService(tt.opts)
			if tt.wantErr != nil {
				assert.EqualError(t, tt.wantErr, err.Error())
			} else {
				assert.Nil(t, err)
			}
		})
	}
}
