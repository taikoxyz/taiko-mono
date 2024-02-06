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
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

var (
	SuccessMsgHash = [32]byte{0x1}
	SuccessId      = big.NewInt(1)
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
	MessagesSent           int
	MessageStatusesChanged int
	ErrorsSent             int
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

		sink <- &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				SrcChainId:  1,
				DestChainId: MockChainID.Uint64(),
			},
		}
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

func (b *Bridge) WatchMessageReceived(
	opts *bind.WatchOpts,
	sink chan<- *bridge.BridgeMessageReceived,
	msgHash [][32]byte,
) (event.Subscription, error) {
	s := &Subscription{
		errChan: make(chan error),
	}

	go func(sink chan<- *bridge.BridgeMessageReceived) {
		<-time.After(2 * time.Second)

		sink <- &bridge.BridgeMessageReceived{
			Message: bridge.IBridgeMessage{
				SrcChainId:  1,
				DestChainId: MockChainID.Uint64(),
			},
		}
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

func (b *Bridge) FilterMessageReceived(
	opts *bind.FilterOpts,
	msgHash [][32]byte,
) (*bridge.BridgeMessageReceivedIterator, error) {
	return &bridge.BridgeMessageReceivedIterator{}, nil
}

func (b *Bridge) FilterMessageSent(
	opts *bind.FilterOpts,
	signal [][32]byte,
) (*bridge.BridgeMessageSentIterator, error) {
	return &bridge.BridgeMessageSentIterator{}, nil
}

func (b *Bridge) WatchMessageStatusChanged(
	opts *bind.WatchOpts,
	sink chan<- *bridge.BridgeMessageStatusChanged,
	msgHash [][32]byte,
) (event.Subscription, error) {
	s := &Subscription{
		errChan: make(chan error),
	}

	go func(sink chan<- *bridge.BridgeMessageStatusChanged) {
		<-time.After(2 * time.Second)

		sink <- &bridge.BridgeMessageStatusChanged{}
		b.MessageStatusesChanged++
	}(sink)

	go func(errChan chan error) {
		<-time.After(5 * time.Second)

		errChan <- errors.New("fail")

		s.done = true
		b.ErrorsSent++
	}(s.errChan)

	return s, nil
}

func (b *Bridge) FilterMessageStatusChanged(
	opts *bind.FilterOpts,
	signal [][32]byte,
) (*bridge.BridgeMessageStatusChangedIterator, error) {
	return &bridge.BridgeMessageStatusChangedIterator{}, nil
}

func (b *Bridge) MessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error) {
	if msgHash == SuccessMsgHash {
		return uint8(relayer.EventStatusNew), nil
	}

	if msgHash == FailSignal {
		return uint8(relayer.EventStatusFailed), nil
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

func (b *Bridge) ProveMessageReceived(opts *bind.CallOpts, message bridge.IBridgeMessage, proof []byte) (bool, error) {
	if message.Id.Uint64() == SuccessId.Uint64() {
		return true, nil
	}

	return false, nil
}

func (b *Bridge) ParseMessageSent(log types.Log) (*bridge.BridgeMessageSent, error) {
	return &bridge.BridgeMessageSent{}, nil
}
