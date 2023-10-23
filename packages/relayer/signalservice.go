package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

type SignalService interface {
	GetSignalSlot(opts *bind.CallOpts, chainId *big.Int, app common.Address, signal [32]byte) ([32]byte, error)
}
