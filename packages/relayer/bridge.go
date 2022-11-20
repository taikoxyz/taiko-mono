package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
)

type Bridge interface {
	WatchMessageSent(
		opts *bind.WatchOpts,
		sink chan<- *contracts.BridgeMessageSent,
		signal [][32]byte,
	) (event.Subscription, error)
	FilterMessageSent(opts *bind.FilterOpts, signal [][32]byte) (*contracts.BridgeMessageSentIterator, error)
	GetMessageStatus(opts *bind.CallOpts, signal [32]byte) (uint8, error)
	ProcessMessage(opts *bind.TransactOpts, message contracts.IBridgeMessage, proof []byte) (*types.Transaction, error)
	IsMessageReceived(opts *bind.CallOpts, signal [32]byte, srcChainId *big.Int, proof []byte) (bool, error) // nolint
}
