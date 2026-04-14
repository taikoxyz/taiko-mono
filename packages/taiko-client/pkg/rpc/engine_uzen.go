package rpc

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
)

// IsUzen returns whether the given chain and timestamp are inside the Uzen fork.
func IsUzen(chainID *big.Int, devnetUzenTime uint64, timestamp uint64) bool {
	if chainID == nil {
		return false
	}

	if chainID.Uint64() == params.TaikoInternalNetworkID.Uint64() && devnetUzenTime != 0 {
		return timestamp >= devnetUzenTime
	}

	genesis := core.TaikoGenesisBlock(chainID.Uint64())
	return genesis != nil && genesis.Config != nil && genesis.Config.ChainID != nil &&
		genesis.Config.ChainID.Cmp(chainID) == 0 && genesis.Config.IsUzen(timestamp)
}

// ForkLabel returns the active fork label for display purposes.
func ForkLabel(chainID *big.Int, devnetUzenTime uint64, timestamp uint64) string {
	if IsUzen(chainID, devnetUzenTime, timestamp) {
		return "Uzen"
	}

	return "Shasta"
}

// NormalizeExecutableData preserves Uzen header difficulty when present on the envelope.
func NormalizeExecutableData(
	chainID *big.Int,
	devnetUzenTime uint64,
	payload *engine.ExecutableData,
	blockValue *big.Int,
) (*engine.ExecutableData, error) {
	if payload == nil {
		return nil, nil
	}

	normalized := *payload
	if IsUzen(chainID, devnetUzenTime, payload.Timestamp) {
		if blockValue == nil {
			return nil, fmt.Errorf("missing blockValue for Uzen payload")
		}

		normalized.HeaderDifficulty = new(big.Int).Set(blockValue)
	}

	return &normalized, nil
}
