package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
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
}
