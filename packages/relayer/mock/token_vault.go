package mock

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type TokenVault struct {
}

func (t *TokenVault) CanonicalToBridged(
	opts *bind.CallOpts,
	chainID *big.Int,
	canonicalAddress common.Address,
) (common.Address, error) {
	return relayer.ZeroAddress, nil
}
