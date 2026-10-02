package rpc

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// taikoChainConfig returns the chain config of the given Taiko network, or nil for a nil chain ID or a chain
// that is not a Taiko network. It reads core.TaikoChainConfig, which skips decoding the genesis alloc, so fork
// checks stay cheap enough to run per block; its fork-time fields reference taiko-geth's package variables, so
// devnet overrides apply.
func taikoChainConfig(chainID *big.Int) *params.ChainConfig {
	if chainID == nil {
		return nil
	}

	config := core.TaikoChainConfig(chainID.Uint64())
	if config == nil || config.ChainID == nil || config.ChainID.Cmp(chainID) != 0 {
		return nil
	}

	return config
}

// IsUnzen returns whether the given chain and timestamp are inside the Unzen fork.
func IsUnzen(chainID *big.Int, timestamp uint64) bool {
	config := taikoChainConfig(chainID)
	return config != nil && config.IsUnzen(timestamp)
}

// DerivationSourceMaxBlocks returns the per-source derivation block limit for a proposal.
func DerivationSourceMaxBlocks(chainID *big.Int, proposalTimestamp uint64) int {
	if IsUnzen(chainID, proposalTimestamp) {
		return manifest.UnzenProposalMaxBlocks
	}

	return manifest.ProposalMaxBlocks
}

// ForkLabel returns the active fork label for display purposes.
func ForkLabel(chainID *big.Int, timestamp uint64) string {
	switch {
	case IsEtna(chainID, timestamp):
		return "Etna"
	case IsUnzen(chainID, timestamp):
		return "Unzen"
	default:
		return "Shasta"
	}
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
