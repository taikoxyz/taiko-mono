package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
)

type SignalService interface {
	GetSignalSlot(opts *bind.CallOpts, chainId uint64, app common.Address, signal [32]byte) ([32]byte, error)
	FilterChainDataSynced(opts *bind.FilterOpts, chainid []uint64, blockId []uint64, kind [][32]byte) (*signalservice.SignalServiceChainDataSyncedIterator, error)
	WatchChainDataSynced(
		opts *bind.WatchOpts,
		sink chan<- *signalservice.SignalServiceChainDataSynced,
		chainid []uint64,
		blockId []uint64,
		kind [][32]byte,
	) (event.Subscription, error)
}
