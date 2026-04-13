package rpc

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
)

// IsUzen returns whether the given chain and timestamp are inside the Uzen fork.
func IsUzen(chainID *big.Int, timestamp uint64) bool {
	if chainID == nil {
		return false
	}

	genesis := core.TaikoGenesisBlock(chainID.Uint64())
	return genesis != nil && genesis.Config != nil && genesis.Config.ChainID != nil &&
		genesis.Config.ChainID.Cmp(chainID) == 0 && genesis.Config.IsUzen(timestamp)
}

// NormalizeExecutableData preserves Uzen header difficulty when present on the envelope.
func NormalizeExecutableData(
	chainID *big.Int,
	payload *engine.ExecutableData,
	blockValue *big.Int,
) (*engine.ExecutableData, error) {
	if payload == nil {
		return nil, nil
	}

	normalized := *payload
	if IsUzen(chainID, payload.Timestamp) {
		if blockValue == nil {
			return nil, fmt.Errorf("missing blockValue for Uzen payload")
		}

		normalized.HeaderDifficulty = new(big.Int).Set(blockValue)
	}

	return &normalized, nil
}

// NormalizedDifficulty returns the expected difficulty for canonical block checks.
func NormalizedDifficulty(chainID *big.Int, timestamp uint64, difficulty *big.Int) *big.Int {
	if IsUzen(chainID, timestamp) {
		if difficulty == nil {
			return common.Big0
		}

		return new(big.Int).Set(difficulty)
	}

	return common.Big0
}
