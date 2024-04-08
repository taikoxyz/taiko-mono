package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

type Bridge interface {
	IsMessageSent(opts *bind.CallOpts, _message bridge.IBridgeMessage) (bool, error)
	FilterMessageSent(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageSentIterator, error)
	FilterMessageReceived(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageReceivedIterator, error)
	MessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error)
	ProcessMessage(opts *bind.TransactOpts, _message bridge.IBridgeMessage, _proof []byte) (*types.Transaction, error)
	FilterMessageStatusChanged(
		opts *bind.FilterOpts,
		msgHash [][32]byte,
	) (*bridge.BridgeMessageStatusChangedIterator, error)
	ParseMessageSent(log types.Log) (*bridge.BridgeMessageSent, error)
	ProofReceipt(opts *bind.CallOpts, msgHash [32]byte) (struct {
		ReceivedAt        uint64
		PreferredExecutor common.Address
	}, error)
	GetInvocationDelays(opts *bind.CallOpts) (*big.Int, *big.Int, error)
	IsMessageReceived(opts *bind.CallOpts, _message bridge.IBridgeMessage, _proof []byte) (bool, error)
	SendMessage(opts *bind.TransactOpts, _message bridge.IBridgeMessage) (*types.Transaction, error)
	SuspendMessages(opts *bind.TransactOpts, _msgHashes [][32]byte, _toSuspend bool) (*types.Transaction, error)
}
