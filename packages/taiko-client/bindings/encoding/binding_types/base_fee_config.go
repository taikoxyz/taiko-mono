package bindingTypes

import (
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
func (b *BaseFeeConfigPacaya) SharingPctgs() uint8 {
	return b.LibSharedDataBaseFeeConfig.SharingPctg
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
	baseFeeSharings uint8
}

// NewBaseFeeConfigShasta creates a new BaseFeeConfigShasta instance.
func NewBaseFeeConfigShasta(
	config *shastaBindings.LibSharedDataBaseFeeConfig,
	baseFeeSharings uint8,
) *BaseFeeConfigShasta {
	return &BaseFeeConfigShasta{LibSharedDataBaseFeeConfig: config, baseFeeSharings: baseFeeSharings}
}

// AdjustmentQuotient returns the adjustment quotient of the base fee config.
func (b *BaseFeeConfigShasta) AdjustmentQuotient() uint8 {
	return b.LibSharedDataBaseFeeConfig.AdjustmentQuotient
}

// SharingPctg returns the sharing percentage of the base fee config.
func (b *BaseFeeConfigShasta) SharingPctgs() uint8 {
	return b.baseFeeSharings
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
