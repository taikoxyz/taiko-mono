package mock

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

type SignalService struct {
}

func (s *SignalService) GetSignalSlot(
	opts *bind.CallOpts,
	chainId uint64,
	app common.Address,
	signal [32]byte,
) ([32]byte, error) {
	return [32]byte{0xff}, nil
}
