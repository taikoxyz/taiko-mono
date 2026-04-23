package rpc

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// IsUnzen returns whether the given chain and timestamp are inside the Unzen fork.
func IsUnzen(chainID *big.Int, timestamp uint64) bool {
	return manifest.IsUnzen(chainID, timestamp)
}

// ForkLabel returns the active fork label for display purposes.
func ForkLabel(chainID *big.Int, timestamp uint64) string {
	if IsUnzen(chainID, timestamp) {
		return "Unzen"
	}

	return "Shasta"
}

// NormalizeExecutableData preserves Unzen header difficulty when present on the envelope.
func NormalizeExecutableData(
	chainID *big.Int,
	payload *engine.ExecutableData,
	blockValue *big.Int,
) (*engine.ExecutableData, error) {
	if payload == nil {
		return nil, nil
	}

	normalized := *payload
	if IsUnzen(chainID, payload.Timestamp) {
		if blockValue == nil {
			return nil, fmt.Errorf("missing blockValue for Unzen payload")
		}

		normalized.HeaderDifficulty = new(big.Int).Set(blockValue)
	}

	return &normalized, nil
}
