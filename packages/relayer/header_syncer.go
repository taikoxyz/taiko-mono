package relayer

import (
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
)

type HeaderSyncer interface {
	GetCrossChainBlockHash(opts *bind.CallOpts, blockId uint64) ([32]byte, error)
}
