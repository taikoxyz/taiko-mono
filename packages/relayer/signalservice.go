package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

type SignalService interface {
	GetSignalSlot(opts *bind.CallOpts, chainId uint64, app common.Address, signal [32]byte) ([32]byte, error)
}
