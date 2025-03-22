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
	// Chain ID for the network
	ChainID *big.Int
	// Ontake switch block (nil = no fork, 0 = already on ontake)
	OntakeForkHeight *big.Int
	// Pacaya switch block (nil = no fork, 0 = already on ontake)
	PacayaForkHeight *big.Int
}

// NewChainConfig creates a new ChainConfig instance.
func NewChainConfig(chainID *big.Int, ontakeForkHeight uint64, pacayaForkHeight uint64) *ChainConfig {
	cfg := &ChainConfig{
		ChainID:          chainID,
		OntakeForkHeight: new(big.Int).SetUint64(ontakeForkHeight),
		PacayaForkHeight: new(big.Int).SetUint64(pacayaForkHeight),
	}

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
	network := NetworkNames[c.ChainID.Uint64()]
	if network == "" {
		network = "unknown"
	}
	banner += fmt.Sprintf("Chain ID:  %v (%s)\n", c.ChainID.Uint64(), network)

	// Create a list of forks with a short description of them.
	banner += "Hard forks (block based):\n"
	banner += fmt.Sprintf(" - Ontake:                   #%-8v\n", c.OntakeForkHeight)
	banner += fmt.Sprintf(" - Pacaya:                   #%-8v\n", c.PacayaForkHeight)
	banner += "\n"

	return banner
}

// IsOntake returns whether num is either equal to the Ontake block or greater.
func (c *ChainConfig) IsOntake(num *big.Int) bool {
	return isBlockForked(c.OntakeForkHeight, num)
}

// IsPacaya returns whether num is either equal to the Pacaya block or greater.
func (c *ChainConfig) IsPacaya(num *big.Int) bool {
	return isBlockForked(c.PacayaForkHeight, num)
}

// isBlockForked returns whether a fork scheduled at block s is active at the
// given head block.
func isBlockForked(s, head *big.Int) bool {
	if s == nil || head == nil {
		return false
	}
	return s.Cmp(head) <= 0
}
