package config

import (
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	bindingTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/binding_types"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Configs is an interface that provides Taiko protocol specific configurations.
type ProtocolConfigs interface {
	BaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig
	BlockMaxGasLimit() uint32
	ForkHeightsOntake() uint64
	ForkHeightsPacaya() uint64
	ForkHeightsShasta() uint64
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
		"baseFeeConfig", configs.BaseFeeConfig(),
		"blockMaxGasLimit", configs.BlockMaxGasLimit(),
		"forkHeightsOntake", configs.ForkHeightsOntake(),
		"forkHeightsPacaya", configs.ForkHeightsPacaya(),
		"forkHeightsShasta", configs.ForkHeightsShasta(),
		"livenessBond", utils.WeiToEther(configs.LivenessBond()),
		"livenessBondPerBlock", utils.WeiToEther(configs.LivenessBondPerBlock()),
		"maxProposals", configs.MaxProposals(),
		"maxBlocksPerBatch", configs.MaxBlocksPerBatch(),
	)
}

// OntakeProtocolConfigs is the configuration for the Ontake fork protocol.
type OntakeProtocolConfigs struct {
	configs          *ontakeBindings.TaikoDataConfig
	pacayaForkHeight uint64
	shastaForkHeight uint64
}

// NewOntakeProtocolConfigs creates a new OntakeProtocolConfigs instance.
func NewOntakeProtocolConfigs(
	configs *ontakeBindings.TaikoDataConfig,
	pacayaForkHeight uint64,
	shastaForkHeight uint64,
) *OntakeProtocolConfigs {
	return &OntakeProtocolConfigs{
		configs:          configs,
		pacayaForkHeight: pacayaForkHeight,
		shastaForkHeight: shastaForkHeight,
	}
}

// BaseFeeConfig implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) BaseFeeConfig() *pacayaBindings.LibSharedDataBaseFeeConfig {
	return &pacayaBindings.LibSharedDataBaseFeeConfig{
		AdjustmentQuotient:     c.configs.BaseFeeConfig.AdjustmentQuotient,
		SharingPctg:            c.configs.BaseFeeConfig.SharingPctg,
		GasIssuancePerSecond:   c.configs.BaseFeeConfig.GasIssuancePerSecond,
		MinGasExcess:           c.configs.BaseFeeConfig.MinGasExcess,
		MaxGasIssuancePerBlock: c.configs.BaseFeeConfig.MaxGasIssuancePerBlock,
	}
}

// ForkHeightsOntake implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) BlockMaxGasLimit() uint32 {
	return c.configs.BlockMaxGasLimit
}

// ForkHeightsOntake implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) ForkHeightsOntake() uint64 {
	return c.configs.OntakeForkHeight
}

// ForkHeightsPacaya implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) ForkHeightsPacaya() uint64 {
	return c.pacayaForkHeight
}

// ForkHeightsShasta implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) ForkHeightsShasta() uint64 {
	return c.shastaForkHeight
}

// LivenessBond implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) LivenessBond() *big.Int {
	return c.configs.LivenessBond
}

// LivenessBondPerBlock implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) LivenessBondPerBlock() *big.Int {
	return common.Big0
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) MaxProposals() uint64 {
	return c.configs.BlockMaxProposals
}

// ProvingWindow implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) ProvingWindow() (time.Duration, error) {
	return 0, fmt.Errorf("proving window is not supported in Ontake protocol configs")
}

// MaxBlocksPerBatch implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) MaxBlocksPerBatch() int {
	return 0
}

// MaxAnchorHeightOffset implements the ProtocolConfigs interface.
func (c *OntakeProtocolConfigs) MaxAnchorHeightOffset() uint64 {
	return c.configs.MaxAnchorHeightOffset
}

// ===============================================================

// PacayaProtocolConfigs is the configuration for the Pacaya fork protocol.
type PacayaProtocolConfigs struct {
	configs *pacayaBindings.ITaikoInboxConfig
}

// NewPacayaProtocolConfigs creates a new PacayaProtocolConfigs instance.
func NewPacayaProtocolConfigs(configs *pacayaBindings.ITaikoInboxConfig) *PacayaProtocolConfigs {
	return &PacayaProtocolConfigs{configs: configs}
}

// BaseFeeConfig implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) BaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig {
	return bindingTypes.NewBaseFeeConfigPacaya(&c.configs.BaseFeeConfig)
}

// ForkHeightsOntake implements the ProtocolConfigs interface.
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

// ForkHeightsShasta implements the ProtocolConfigs interface.
func (c *PacayaProtocolConfigs) ForkHeightsShasta() uint64 {
	return c.configs.ForkHeights.Shasta
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

// ===============================================================

// ShastaProtocolConfigs is the configuration for the Pacaya fork protocol.
type ShastaProtocolConfigs struct {
	configs *shastaBindings.ITaikoInboxConfig
}

// NewShastaProtocolConfigs creates a new ShastaProtocolConfigs instance.
func NewShastaProtocolConfigs(configs *shastaBindings.ITaikoInboxConfig) *ShastaProtocolConfigs {
	return &ShastaProtocolConfigs{configs: configs}
}

// BaseFeeConfig implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) BaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig {
	return bindingTypes.NewBaseFeeConfigShasta(&c.configs.BaseFeeConfig, c.configs.BaseFeeSharings)
}

// ForkHeightsOntake implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) BlockMaxGasLimit() uint32 {
	return c.configs.BlockMaxGasLimit
}

// ForkHeightsOntake implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) ForkHeightsOntake() uint64 {
	return c.configs.ForkHeights.Ontake
}

// ForkHeightsPacaya implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) ForkHeightsPacaya() uint64 {
	return c.configs.ForkHeights.Pacaya
}

// ForkHeightsShasta implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) ForkHeightsShasta() uint64 {
	return c.configs.ForkHeights.Shasta
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) LivenessBond() *big.Int {
	return c.configs.LivenessBond
}

// LivenessBondPerBlock implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) LivenessBondPerBlock() *big.Int {
	return common.Big0
}

// MaxProposals implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) MaxProposals() uint64 {
	return c.configs.MaxUnverifiedBatches
}

// ProvingWindow implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) ProvingWindow() (time.Duration, error) {
	return time.Duration(c.configs.ProvingWindow) * time.Second, nil
}

// MaxBlocksPerBatch implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) MaxBlocksPerBatch() int {
	return int(c.configs.MaxBlocksPerBatch)
}

// MaxAnchorHeightOffset implements the ProtocolConfigs interface.
func (c *ShastaProtocolConfigs) MaxAnchorHeightOffset() uint64 {
	return c.configs.MaxAnchorHeightOffset
}
