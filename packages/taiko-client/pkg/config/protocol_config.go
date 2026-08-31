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
	MaxProposals() uint64
	ProvingWindow() time.Duration
	MaxBlocksPerBatch() int
}

// ReportProtocolConfigs logs the protocol configurations.
func ReportProtocolConfigs(configs ProtocolConfigs) {
	log.Info(
		"Protocol configs",
		"LivenessBond", utils.WeiToEther(configs.LivenessBond()),
		"MaxProposals", configs.MaxProposals(),
		"ProvingWindow", configs.ProvingWindow(),
		"MaxBlocksPerBatch", configs.MaxBlocksPerBatch(),
	)
}

// InboxProtocolConfigs is the configuration for the Shasta protocol.
type InboxProtocolConfigs struct {
	configs *shastaBindings.IInboxConfig
}

// NewInboxProtocolConfigs creates a new InboxProtocolConfigs instance.
func NewInboxProtocolConfigs(configs *shastaBindings.IInboxConfig) *InboxProtocolConfigs {
	return &InboxProtocolConfigs{configs: configs}
}

// LivenessBond implements the ProtocolConfigs interface.
func (c *InboxProtocolConfigs) LivenessBond() *big.Int {
	return new(big.Int).SetUint64(c.configs.LivenessBond)
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *InboxProtocolConfigs) MaxProposals() uint64 {
	if c.configs.RingBufferSize == nil || c.configs.RingBufferSize.Cmp(common.Big0) <= 0 {
		return 0
	}

	return new(big.Int).Sub(c.configs.RingBufferSize, common.Big1).Uint64()
}

// ProvingWindow implements the ProtocolConfigs interface.
func (c *InboxProtocolConfigs) ProvingWindow() time.Duration {
	return time.Duration(c.configs.ProvingWindow.Uint64()) * time.Second
}

// MaxBlocksPerBatch implements the ProtocolConfigs interface.
func (c *InboxProtocolConfigs) MaxBlocksPerBatch() int {
	return manifest.ProposalMaxBlocks
}
