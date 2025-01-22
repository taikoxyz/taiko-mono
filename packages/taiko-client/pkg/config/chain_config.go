package config

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"

	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
)

// ChainConfig is the core config which determines the blockchain settings.
type ChainConfig struct {
	// Ontake switch block (nil = no fork, 0 = already on ontake)
	ProtocolConfigs *bindings.TaikoDataConfig `json:"protocolConfigs"`
}

// NewChainConfig creates a new ChainConfig instance.
func NewChainConfig(protocolConfigs *bindings.TaikoDataConfig) *ChainConfig {
	cfg := &ChainConfig{protocolConfigs}

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
var NetworkNames = map[uint64]string{
	params.TaikoMainnetNetworkID.Uint64():     "Taiko Mainnet",
	params.HeklaNetworkID.Uint64():            "Taiko Hekla Testnet",
	params.TaikoInternalL2ANetworkID.Uint64(): "Taiko Internal Devnet",
}

// Description returns a human-readable description of ChainConfig.
func (c *ChainConfig) Description() string {
	var banner string

	// Create some basic network config output
	network := NetworkNames[c.ProtocolConfigs.ChainId]
	if network == "" {
		network = "unknown"
	}
	banner += fmt.Sprintf("Chain ID:  %v (%s)\n", c.ProtocolConfigs.ChainId, network)

	// Create a list of forks with a short description of them.
	banner += "Hard forks (block based):\n"
	banner += fmt.Sprintf(" - Ontake:                   #%-8v\n", c.ProtocolConfigs.OntakeForkHeight)
	banner += "\n"

	return banner
}

// IsOntake returns whether num is either equal to the ontake block or greater.
func (c *ChainConfig) IsOntake(num *big.Int) bool {
	return isBlockForked(new(big.Int).SetUint64(c.ProtocolConfigs.OntakeForkHeight), num)
}

// isBlockForked returns whether a fork scheduled at block s is active at the
// given head block.
func isBlockForked(s, head *big.Int) bool {
	if s == nil || head == nil {
		return false
	}
	return s.Cmp(head) <= 0
}
