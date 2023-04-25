package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
)

type HeaderSyncer interface {
	GetXchainBlockHash(opts *bind.CallOpts, number *big.Int) ([32]byte, error)
}
