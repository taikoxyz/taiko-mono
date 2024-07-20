package config

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
)

// ChainConfig is the core config which determines the blockchain settings.
type ChainConfig struct {
	ChainID     *big.Int `json:"chainId"`     // ChainId identifies the current chain
	OnTakeBlock *big.Int `json:"onTakeBlock"` // Ontake switch block (nil = no fork, 0 = already on ontake)
}

// NewChainConfig creates a new ChainConfig instance.
func NewChainConfig(chainID *big.Int, onTakeBlock *big.Int) *ChainConfig {
	cfg := &ChainConfig{chainID, onTakeBlock}

	log.Info("")
	log.Info(strings.Repeat("-", 153))
	for _, line := range strings.Split(cfg.Description(), "\n") {
		log.Info(line)
	}
	log.Info(strings.Repeat("-", 153))
	log.Info("")

	return cfg
}

// NetworkNames are user friendly names to use in the chain spec banner.
var NetworkNames = map[string]string{
	params.TaikoMainnetNetworkID.String():     "Taiko Mainnet",
	params.HeklaNetworkID.String():            "Taiko Hekla Testnet",
	params.TaikoInternalL2ANetworkID.String(): "Taiko Internal Devnet",
}

// Description returns a human-readable description of ChainConfig.
func (c *ChainConfig) Description() string {
	var banner string

	// Create some basic network config output
	network := NetworkNames[c.ChainID.String()]
	if network == "" {
		network = "unknown"
	}
	banner += fmt.Sprintf("Chain ID:  %v (%s)\n", c.ChainID, network)

	// Create a list of forks with a short description of them.
	banner += "Hard forks (block based):\n"
	banner += fmt.Sprintf(" - Ontake:                   #%-8v\n", c.OnTakeBlock)
	banner += "\n"

	return banner
}

// IsOntake returns whether num is either equal to the ontake block or greater.
func (c *ChainConfig) IsOntake(num *big.Int) bool {
	return isBlockForked(c.OnTakeBlock, num)
}

// isBlockForked returns whether a fork scheduled at block s is active at the
// given head block.
func isBlockForked(s, head *big.Int) bool {
	if s == nil || head == nil {
		return false
	}
	return s.Cmp(head) <= 0
}
