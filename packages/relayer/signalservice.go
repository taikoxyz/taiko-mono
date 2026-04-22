package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

// SignalService exposes functionality shared between legacy and v4
// signal service contracts.
type SignalService interface {
	GetSignalSlot(opts *bind.CallOpts, _chainId uint64, _app common.Address, _signal [32]byte) ([32]byte, error)
}
