package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

type QuotaManager interface {
	AvailableQuota(opts *bind.CallOpts, _token common.Address, _leap *big.Int) (*big.Int, error)
	QuotaPeriod(opts *bind.CallOpts) (*big.Int, error)
}
