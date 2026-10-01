package rpc

import (
	"math/big"

	"github.com/ethereum/go-ethereum/core"
)

// IsEtna returns whether the given chain and timestamp are inside the Etna fork, which removes the
// anchor transaction and commits each block's L1 anchor block hash as its parentBeaconBlockRoot.
func IsEtna(chainID *big.Int, timestamp uint64) bool {
	if chainID == nil {
		return false
	}

	genesis := core.TaikoGenesisBlock(chainID.Uint64())
	return genesis != nil && genesis.Config != nil && genesis.Config.ChainID != nil &&
		genesis.Config.ChainID.Cmp(chainID) == 0 && genesis.Config.IsEtna(timestamp)
}
