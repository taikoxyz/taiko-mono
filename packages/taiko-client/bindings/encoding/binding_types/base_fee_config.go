package bindingTypes

import (
	"github.com/ethereum/go-ethereum/core"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// BaseFeeConfigPacayas represents a base fee config from TaikoInbox for the Pacaya fork.
type BaseFeeConfigPacaya struct {
	*pacayaBindings.LibSharedDataBaseFeeConfig
}

// NewBaseFeeConfigPacaya creates a new BaseFeeConfigPacaya instance.
func NewBaseFeeConfigPacaya(config *pacayaBindings.LibSharedDataBaseFeeConfig) *BaseFeeConfigPacaya {
	return &BaseFeeConfigPacaya{LibSharedDataBaseFeeConfig: config}
}

// AdjustmentQuotient returns the adjustment quotient of the base fee config.
func (b *BaseFeeConfigPacaya) AdjustmentQuotient() uint8 {
	return b.LibSharedDataBaseFeeConfig.AdjustmentQuotient
}

// SharingPctg returns the sharing percentage of the base fee config.
func (b *BaseFeeConfigPacaya) SharingPctgs() [2]uint8 {
	return [2]uint8{b.LibSharedDataBaseFeeConfig.SharingPctg, 0}
}

// GasIssuancePerSecond returns the gas issuance per second of the base fee config.
func (b *BaseFeeConfigPacaya) GasIssuancePerSecond() uint32 {
	return b.LibSharedDataBaseFeeConfig.GasIssuancePerSecond
}

// MinGasExcess returns the minimum gas excess of the base fee config.
func (b *BaseFeeConfigPacaya) MinGasExcess() uint64 {
	return b.LibSharedDataBaseFeeConfig.MinGasExcess
}

// MaxGasIssuancePerBlock returns the maximum gas issuance per block of the base fee config.
func (b *BaseFeeConfigPacaya) MaxGasIssuancePerBlock() uint32 {
	return b.LibSharedDataBaseFeeConfig.MaxGasIssuancePerBlock
}

// BaseFeeConfigShasta represents a base fee config from TaikoInbox for the Shasta fork.
type BaseFeeConfigShasta struct {
	*shastaBindings.LibSharedDataBaseFeeConfig
	*shastaBindings.ITaikoInboxBatchInfo
}

// NewBaseFeeConfigShasta creates a new BaseFeeConfigShasta instance.
func NewBaseFeeConfigShasta(
	config *shastaBindings.LibSharedDataBaseFeeConfig,
	batchInfo *shastaBindings.ITaikoInboxBatchInfo,
) *BaseFeeConfigShasta {
	return &BaseFeeConfigShasta{LibSharedDataBaseFeeConfig: config, ITaikoInboxBatchInfo: batchInfo}
}

// AdjustmentQuotient returns the adjustment quotient of the base fee config.
func (b *BaseFeeConfigShasta) AdjustmentQuotient() uint8 {
	return b.LibSharedDataBaseFeeConfig.AdjustmentQuotient
}

// SharingPctg returns the sharing percentage of the base fee config.
func (b *BaseFeeConfigShasta) SharingPctgs() [2]uint8 {
	return core.DecodeExtraData(b.ExtraData[:])
}

// GasIssuancePerSecond returns the gas issuance per second of the base fee config.
func (b *BaseFeeConfigShasta) GasIssuancePerSecond() uint32 {
	return b.LibSharedDataBaseFeeConfig.GasIssuancePerSecond
}

// MinGasExcess returns the minimum gas excess of the base fee config.
func (b *BaseFeeConfigShasta) MinGasExcess() uint64 {
	return b.LibSharedDataBaseFeeConfig.MinGasExcess
}

// MaxGasIssuancePerBlock returns the maximum gas issuance per block of the base fee config.
func (b *BaseFeeConfigShasta) MaxGasIssuancePerBlock() uint32 {
	return b.LibSharedDataBaseFeeConfig.MaxGasIssuancePerBlock
}
