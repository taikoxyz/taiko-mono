package mock

import (
	"errors"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
)

type SignalService struct {
	MessagesSent           int
	MessageStatusesChanged int
	ErrorsSent             int
}

func (s *SignalService) GetSignalSlot(
	opts *bind.CallOpts,
	chainId uint64,
	app common.Address,
	signal [32]byte,
) ([32]byte, error) {
	return [32]byte{0xff}, nil
}

func (s *SignalService) GetSyncedChainData(opts *bind.CallOpts, chainId uint64, kind [32]byte, blockId uint64) (struct {
	BlockId   uint64
	ChainData [32]byte
}, error) {
	return struct {
		BlockId   uint64
		ChainData [32]byte
	}{
		BlockId:   1,
		ChainData: [32]byte{},
	}, nil
}

func (s *SignalService) FilterChainDataSynced(opts *bind.FilterOpts, chainid []uint64, blockId []uint64, kind [][32]byte) (*signalservice.SignalServiceChainDataSyncedIterator, error) {
	return &signalservice.SignalServiceChainDataSyncedIterator{}, nil
}

func (s *SignalService) WatchChainDataSynced(
	opts *bind.WatchOpts,
	sink chan<- *signalservice.SignalServiceChainDataSynced, chainid []uint64, blockId []uint64, kind [][32]byte) (event.Subscription, error) {

	sub := &Subscription{
		errChan: make(chan error),
	}

	go func(sink chan<- *signalservice.SignalServiceChainDataSynced) {
		<-time.After(2 * time.Second)

		sink <- &signalservice.SignalServiceChainDataSynced{
			Chainid: 1,
			BlockId: 1,
			Kind:    [32]byte{},
			Data:    [32]byte{},
			Signal:  [32]byte{},
		}

		s.MessagesSent++
	}(sink)

	go func(errChan chan error) {
		<-time.After(5 * time.Second)

		errChan <- errors.New("fail")

		sub.done = true

		s.ErrorsSent++
	}(sub.errChan)

	return sub, nil
}
