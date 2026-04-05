package config

import (
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Configs is an interface that provides Taiko protocol specific configurations.
type ProtocolConfigs interface {
	LivenessBond() *big.Int
	LivenessBondPerBlock() *big.Int
	MaxProposals() uint64
	ProvingWindow() time.Duration
	MaxBlocksPerBatch() int
	MaxAnchorHeightOffset() uint64
}

// ReportProtocolConfigs logs the protocol configurations.
func ReportProtocolConfigs(configs ProtocolConfigs) {
	log.Info(
		"Protocol configs",
		"LivenessBond", utils.WeiToEther(configs.LivenessBond()),
		"LivenessBondPerBlock", utils.WeiToEther(configs.LivenessBondPerBlock()),
		"MaxProposals", configs.MaxProposals(),
		"ProvingWindow", configs.ProvingWindow(),
		"MaxBlocksPerBatch", configs.MaxBlocksPerBatch(),
	)
}

// ShastaProtocolConfigs is the configuration for the Shasta protocol.
type ShastaProtocolConfigs struct {
	configs *shastaBindings.IInboxConfig
}

// NewShastaProtocolConfigs creates a new ShastaProtocolConfigs instance.
func NewShastaProtocolConfigs(configs *shastaBindings.IInboxConfig) *ShastaProtocolConfigs {
	return &ShastaProtocolConfigs{configs: configs}
}

// LivenessBond implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) LivenessBond() *big.Int {
	return new(big.Int).SetUint64(c.configs.LivenessBond)
}

// LivenessBondPerBlock implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) LivenessBondPerBlock() *big.Int {
	return common.Big0
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) MaxProposals() uint64 {
	if c.configs.RingBufferSize == nil || c.configs.RingBufferSize.Cmp(common.Big0) <= 0 {
		return 0
	}

	return new(big.Int).Sub(c.configs.RingBufferSize, common.Big1).Uint64()
}

// ProvingWindow implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) ProvingWindow() time.Duration {
	return time.Duration(c.configs.ProvingWindow.Uint64()) * time.Second
}

// MaxBlocksPerBatch implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) MaxBlocksPerBatch() int {
	return manifest.ProposalMaxBlocks
}

// MaxAnchorHeightOffset implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) MaxAnchorHeightOffset() uint64 {
	return 0
}
