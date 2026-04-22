package mock

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

type QuotaManager struct {
}

func (q *QuotaManager) AvailableQuota(opts *bind.CallOpts, _token common.Address, _leap *big.Int) (*big.Int, error) {
	return big.NewInt(10000), nil
}

func (q *QuotaManager) QuotaPeriod(opts *bind.CallOpts) (*big.Int, error) {
	return big.NewInt(10), nil
}
