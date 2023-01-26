package mock

import (
	"errors"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

var (
	SuccessMsgHash = [32]byte{0x1}
	FailSignal     = [32]byte{0x2}
)

var dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"

var ProcessMessageTx = types.NewTransaction(
	PendingNonce,
	common.HexToAddress(dummyAddress),
	big.NewInt(1),
	100,
	big.NewInt(10),
	nil,
)

type Bridge struct {
	MessagesSent int
	ErrorsSent   int
}

type Subscription struct {
	errChan chan error
	done    bool
}

func (s *Subscription) Err() <-chan error {
	return s.errChan
}

func (s *Subscription) Unsubscribe() {}

func (b *Bridge) WatchMessageSent(
	opts *bind.WatchOpts,
	sink chan<- *bridge.BridgeMessageSent,
	msgHash [][32]byte,
) (event.Subscription, error) {
	s := &Subscription{
		errChan: make(chan error),
	}

	go func(sink chan<- *bridge.BridgeMessageSent) {
		<-time.After(2 * time.Second)

		sink <- &bridge.BridgeMessageSent{}
		b.MessagesSent++
	}(sink)

	go func(errChan chan error) {
		<-time.After(5 * time.Second)

		errChan <- errors.New("fail")

		s.done = true
		b.ErrorsSent++
	}(s.errChan)

	return s, nil
}

func (b *Bridge) FilterMessageSent(
	opts *bind.FilterOpts,
	signal [][32]byte,
) (*bridge.BridgeMessageSentIterator, error) {
	return &bridge.BridgeMessageSentIterator{}, nil
}

func (b *Bridge) GetMessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error) {
	if msgHash == SuccessMsgHash {
		return uint8(relayer.EventStatusNew), nil
	}

	return uint8(relayer.EventStatusDone), nil
}

func (b *Bridge) ProcessMessage(
	opts *bind.TransactOpts,
	message bridge.IBridgeMessage,
	proof []byte,
) (*types.Transaction, error) {
	return ProcessMessageTx, nil
}

func (b *Bridge) IsMessageReceived(opts *bind.CallOpts, signal [32]byte, srcChainId *big.Int, proof []byte) (bool, error) { // nolint
	if signal == SuccessMsgHash {
		return true, nil
	}

	return false, nil
}
