package bindings

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
	"math/big"
)

type Bridge interface {
	IsMessageSent(opts *bind.CallOpts, _message bridge.IBridgeMessage) (bool, error)
	FilterMessageSent(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageSentIterator, error)
	FilterMessageProcessed(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageProcessedIterator, error)
	MessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error)
	ProcessMessage(opts *bind.TransactOpts, _message bridge.IBridgeMessage, _proof []byte) (*types.Transaction, error)
	FilterMessageStatusChanged(
		opts *bind.FilterOpts,
		msgHash [][32]byte,
	) (*bridge.BridgeMessageStatusChangedIterator, error)
	ParseMessageSent(log types.Log) (*bridge.BridgeMessageSent, error)
	IsMessageReceived(opts *bind.CallOpts, _message bridge.IBridgeMessage, _proof []byte) (bool, error)
	SendMessage(opts *bind.TransactOpts, _message bridge.IBridgeMessage) (*types.Transaction, error)
	Paused(opts *bind.CallOpts) (bool, error)
}

type QuotaManager interface {
	AvailableQuota(opts *bind.CallOpts, _token common.Address, _leap *big.Int) (*big.Int, error)
	QuotaPeriod(opts *bind.CallOpts) (*big.Int, error)
}

type SignalService interface {
	GetSignalSlot(opts *bind.CallOpts, _chainId uint64, _app common.Address, _signal [32]byte) ([32]byte, error)
	FilterChainDataSynced(
		opts *bind.FilterOpts,
		chainid []uint64,
		blockId []uint64,
		kind [][32]byte,
	) (*signalservice.SignalServiceChainDataSyncedIterator, error)
	GetSyncedChainData(opts *bind.CallOpts, _chainId uint64, _kind [32]byte, _blockId uint64) (struct {
		BlockId   uint64
		ChainData [32]byte
	}, error)
}

type TokenVault interface {
	CanonicalToBridged(
		opts *bind.CallOpts,
		chainID *big.Int,
		canonicalAddress common.Address,
	) (common.Address, error)
}
