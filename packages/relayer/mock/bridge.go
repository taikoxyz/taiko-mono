package mock

import (
	"errors"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

var (
	SuccessSignal = [32]byte{0x1}
	FailSignal    = [32]byte{0x2}
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
	sink chan<- *contracts.BridgeMessageSent,
	signal [][32]byte,
) (event.Subscription, error) {
	s := &Subscription{
		errChan: make(chan error),
	}

	go func(sink chan<- *contracts.BridgeMessageSent) {
		<-time.After(2 * time.Second)

		sink <- &contracts.BridgeMessageSent{}
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
) (*contracts.BridgeMessageSentIterator, error) {
	return &contracts.BridgeMessageSentIterator{}, nil
}

func (b *Bridge) GetMessageStatus(opts *bind.CallOpts, signal [32]byte) (uint8, error) {
	if signal == SuccessSignal {
		return uint8(relayer.EventStatusNew), nil
	}

	return uint8(relayer.EventStatusDone), nil
}

func (b *Bridge) ProcessMessage(
	opts *bind.TransactOpts,
	message contracts.IBridgeMessage,
	proof []byte,
) (*types.Transaction, error) {
	return &types.Transaction{}, nil
}

func (b *Bridge) IsMessageReceived(opts *bind.CallOpts, signal [32]byte, srcChainId *big.Int, proof []byte) (bool, error) { // nolint
	if signal == SuccessSignal {
		return true, nil
	}

	return false, nil
}
