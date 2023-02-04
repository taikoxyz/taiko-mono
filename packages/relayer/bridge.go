package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

type Bridge interface {
	WatchMessageSent(
		opts *bind.WatchOpts,
		sink chan<- *bridge.BridgeMessageSent,
		msgHash [][32]byte,
	) (event.Subscription, error)
	FilterMessageSent(opts *bind.FilterOpts, msgHash [][32]byte) (*bridge.BridgeMessageSentIterator, error)
	GetMessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error)
	ProcessMessage(opts *bind.TransactOpts, message bridge.IBridgeMessage, proof []byte) (*types.Transaction, error)
	IsMessageReceived(opts *bind.CallOpts, msgHash [32]byte, srcChainId *big.Int, proof []byte) (bool, error) // nolint
}
