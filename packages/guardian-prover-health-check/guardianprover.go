package guardianproverhealthcheck

import (
	"math/big"
	"net/url"

	"github.com/ethereum/go-ethereum/common"
)

type GuardianProver struct {
	Address  common.Address
	ID       *big.Int
	Endpoint *url.URL
}
