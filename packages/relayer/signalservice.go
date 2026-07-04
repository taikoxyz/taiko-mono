package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
)

type SignalService interface {
	GetSignalSlot(opts *bind.CallOpts, _chainId uint64, _app common.Address, _signal [32]byte) ([32]byte, error)
	FilterChainDataSynced(
		opts *bind.FilterOpts,
		chainid []uint64,
		blockId []uint64,
		kind [][32]byte,
	) (*signalservice.SignalServiceChainDataSyncedIterator, error)
	GetSyncedChainData(opts *bind.CallOpts, _chainId uint64, _kind [32]byte, _blockId uint64) (struct {
		BlockId   uint64
		ChainData [32]byte
	}, error)
}
