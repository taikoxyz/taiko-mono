package rpc

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/core"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

// IsUnzen returns whether the given chain and timestamp are inside the Unzen fork.
func IsUnzen(chainID *big.Int, timestamp uint64) bool {
	if chainID == nil {
		return false
	}

	genesis := core.TaikoGenesisBlock(chainID.Uint64())
	return genesis != nil && genesis.Config != nil && genesis.Config.ChainID != nil &&
		genesis.Config.ChainID.Cmp(chainID) == 0 && genesis.Config.IsUnzen(timestamp)
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
