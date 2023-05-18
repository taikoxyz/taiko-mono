package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

type TokenVault interface {
	CanonicalToBridged(
		opts *bind.CallOpts,
		chainID *big.Int,
		canonicalAddress common.Address,
	) (common.Address, error)
}
