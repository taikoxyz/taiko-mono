package config

import (
	"fmt"
	"math"
	"math/big"
	"strings"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
)

// ChainConfig is the core config which determines the blockchain settings.
type ChainConfig struct {
	// Chain ID for the network
	ChainID *big.Int
}

// forkInfo holds the block numbers and timestamps for the various hard forks.
type forkInfo struct {
	ontakeBlock *big.Int
	pacayaBlock *big.Int
	shastaTime  uint64
	uzenTime    uint64
}

// NewChainConfig creates a new ChainConfig instance.
func NewChainConfig(chainID *big.Int, _ uint64) *ChainConfig {
	cfg := &ChainConfig{
		ChainID: chainID,
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
	params.TaikoInternalNetworkID.Uint64(): "Taiko Internal Devnet",
	params.MasayaDevnetNetworkID.Uint64():  "Taiko Masaya Devnet",
	params.TaikoHoodiNetworkID.Uint64():    "Taiko Hoodi Testnet",
	params.TaikoMainnetNetworkID.Uint64():  "Taiko Mainnet",
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
	banner += "Hard forks:\n"
	banner += "\n"
	if forks, ok := c.forkInfo(); ok {
		banner += fmt.Sprintf(" - Ontake:                   %s\n", formatForkBlock(forks.ontakeBlock))
		banner += fmt.Sprintf(" - Pacaya:                   %s\n", formatForkBlock(forks.pacayaBlock))
		banner += fmt.Sprintf(" - Shasta:                   %s\n", formatForkTime(forks.shastaTime))
		banner += fmt.Sprintf(" - Uzen:                     %s", formatForkTime(forks.uzenTime))
	}
	banner += "\n"

	return banner
}

// formatForkBlock formats the fork block number for display, handling nil values as "inactive".
func formatForkBlock(block *big.Int) string {
	if block == nil {
		return "inactive"
	}

	return fmt.Sprintf("#%v", block)
}

// formatForkTime formats the fork time for display, handling math.MaxUint64 as "inactive".
func formatForkTime(ts uint64) string {
	if ts == math.MaxUint64 {
		return "inactive"
	}

	return fmt.Sprintf("@%v", ts)
}

// forkInfo returns the fork information for the chain, if available.
func (c *ChainConfig) forkInfo() (forkInfo, bool) {
	switch c.ChainID.Uint64() {
	case params.TaikoInternalNetworkID.Uint64():
		return forkInfo{
			ontakeBlock: gethcore.InternalDevnetOntakeBlock,
			pacayaBlock: gethcore.InternalDevnetPacayaBlock,
			shastaTime:  gethcore.InternalShastaTime,
			uzenTime:    gethcore.InternalUzenTime,
		}, true
	case params.MasayaDevnetNetworkID.Uint64():
		return forkInfo{
			ontakeBlock: gethcore.MasayaDevnetOntakeBlock,
			pacayaBlock: gethcore.MasayaDevnetPacayaBlock,
			shastaTime:  gethcore.MasayaShastaTime,
			uzenTime:    gethcore.MasayaUzenTime,
		}, true
	case params.TaikoHoodiNetworkID.Uint64():
		return forkInfo{
			ontakeBlock: gethcore.TaikoHoodiOntakeBlock,
			pacayaBlock: gethcore.TaikoHoodiPacayaBlock,
			shastaTime:  gethcore.HoodiShastaTime,
			uzenTime:    gethcore.HoodiUzenTime,
		}, true
	case params.TaikoMainnetNetworkID.Uint64():
		return forkInfo{
			ontakeBlock: gethcore.MainnetOntakeBlock,
			pacayaBlock: gethcore.MainnetPacayaBlock,
			shastaTime:  gethcore.MainnetShastaTime,
			uzenTime:    gethcore.MainnetUzenTime,
		}, true
	default:
		return forkInfo{}, false
	}
}
