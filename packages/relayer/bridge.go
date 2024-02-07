package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

type Bridge interface {
	IsMessageSent(opts *bind.CallOpts, message bridge.IBridgeMessage) (bool, error)
	WatchMessageSent(
		opts *bind.WatchOpts,
		sink chan<- *bridge.BridgeMessageSent,
		msgHash [][32]byte,
	) (event.Subscription, error)
	WatchMessageReceived(
		opts *bind.WatchOpts,
		sink chan<- *bridge.BridgeMessageReceived,
		msgHash [][32]byte,
	) (event.Subscription, error)
	FilterMessageSent(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageSentIterator, error)
	FilterMessageReceived(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageReceivedIterator, error)
	MessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error)
	ProcessMessage(opts *bind.TransactOpts, message bridge.IBridgeMessage, proof []byte) (*types.Transaction, error)
	ProveMessageReceived(opts *bind.CallOpts, message bridge.IBridgeMessage, proof []byte) (bool, error)
	FilterMessageStatusChanged(
		opts *bind.FilterOpts,
		msgHash [][32]byte,
	) (*bridge.BridgeMessageStatusChangedIterator, error)
	WatchMessageStatusChanged(
		opts *bind.WatchOpts,
		sink chan<- *bridge.BridgeMessageStatusChanged,
		msgHash [][32]byte,
	) (event.Subscription, error)
	ParseMessageSent(log types.Log) (*bridge.BridgeMessageSent, error)
	ProofReceipt(opts *bind.CallOpts, msgHash [32]byte) (struct {
		ReceivedAt        uint64
		PreferredExecutor common.Address
	}, error)
	GetInvocationDelays(opts *bind.CallOpts) (struct {
		InvocationDelay      *big.Int
		InvocationExtraDelay *big.Int
	}, error)
	SuspendMessages(opts *bind.TransactOpts, msgHashes [][32]byte, toSuspend bool) (*types.Transaction, error)
}
