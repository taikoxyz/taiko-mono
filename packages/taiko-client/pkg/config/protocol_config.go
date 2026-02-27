package config

import (
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Configs is an interface that provides Taiko protocol specific configurations.
type ProtocolConfigs interface {
	BaseFeeConfig() *pacayaBindings.LibSharedDataBaseFeeConfig
	BlockMaxGasLimit() uint32
	ForkHeightsOntake() uint64
	ForkHeightsPacaya() uint64
	ForkTimeShasta() uint64
	LivenessBond() *big.Int
	LivenessBondPerBlock() *big.Int
	MaxProposals() uint64
	ProvingWindow() (time.Duration, error)
	MaxBlocksPerBatch() int
	MaxAnchorHeightOffset() uint64
}

// ReportProtocolConfigs logs the protocol configurations.
func ReportProtocolConfigs(configs ProtocolConfigs) {
	log.Info(
		"Protocol configs",
		"BaseFeeConfig", configs.BaseFeeConfig(),
		"BlockMaxGasLimit", configs.BlockMaxGasLimit(),
		"ForkHeightsOntake", configs.ForkHeightsOntake(),
		"ForkHeightsPacaya", configs.ForkHeightsPacaya(),
		"ForkTimeShasta", configs.ForkTimeShasta(),
		"LivenessBond", utils.WeiToEther(configs.LivenessBond()),
		"LivenessBondPerBlock", utils.WeiToEther(configs.LivenessBondPerBlock()),
		"MaxProposals", configs.MaxProposals(),
		"MaxBlocksPerBatch", configs.MaxBlocksPerBatch(),
	)
}

// PacayaProtocolConfigs is the configuration for the Pacaya fork protocol.
type PacayaProtocolConfigs struct {
	configs        *pacayaBindings.ITaikoInboxConfig
	shastaForkTime uint64
}

// NewPacayaProtocolConfigs creates a new PacayaProtocolConfigs instance.
func NewPacayaProtocolConfigs(
	configs *pacayaBindings.ITaikoInboxConfig,
	shastaForkTime uint64,
) *PacayaProtocolConfigs {
	return &PacayaProtocolConfigs{configs: configs, shastaForkTime: shastaForkTime}
}

// BaseFeeConfig implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) BaseFeeConfig() *pacayaBindings.LibSharedDataBaseFeeConfig {
	return &c.configs.BaseFeeConfig
}

// BlockMaxGasLimit implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) BlockMaxGasLimit() uint32 {
	return c.configs.BlockMaxGasLimit
}

// ForkHeightsOntake implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) ForkHeightsOntake() uint64 {
	return c.configs.ForkHeights.Ontake
}

// ForkHeightsPacaya implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) ForkHeightsPacaya() uint64 {
	return c.configs.ForkHeights.Pacaya
}

// ForkTimeShasta implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) ForkTimeShasta() uint64 {
	return c.shastaForkTime
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) LivenessBond() *big.Int {
	return c.configs.LivenessBondBase
}

// LivenessBondPerBlock implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) LivenessBondPerBlock() *big.Int {
	return c.configs.LivenessBondPerBlock
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) MaxProposals() uint64 {
	return c.configs.MaxUnverifiedBatches
}

// ProvingWindow implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) ProvingWindow() (time.Duration, error) {
	return time.Duration(c.configs.ProvingWindow) * time.Second, nil
}

// MaxBlocksPerBatch implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) MaxBlocksPerBatch() int {
	return int(c.configs.MaxBlocksPerBatch)
}

// MaxAnchorHeightOffset implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) MaxAnchorHeightOffset() uint64 {
	return c.configs.MaxAnchorHeightOffset
}
