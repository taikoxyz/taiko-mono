package rpc

import (
	"math/big"
)

// IsEtna returns whether the given chain and timestamp are inside the Etna fork, which removes the
// anchor transaction and commits each block's L1 anchor block hash as its parentBeaconBlockRoot.
func IsEtna(chainID *big.Int, timestamp uint64) bool {
	config := taikoChainConfig(chainID)
	return config != nil && config.IsEtna(timestamp)
}
