package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

var (
	livenessBond, _             = new(big.Int).SetString("125000000000000000000", 10)
	InternlDevnetProtocolConfig = &bindings.TaikoDataConfig{
		ChainId:               params.TaikoInternalL2ANetworkID.Uint64(),
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   360_000,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		OntakeForkHeight:      2,
		BaseFeeConfig: bindings.LibSharedDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			SharingPctg:            75,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 600_000_000,
		},
	}
	HeklaProtocolConfig = &bindings.TaikoDataConfig{
		ChainId:               params.HeklaNetworkID.Uint64(),
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   324_512,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		OntakeForkHeight:      840_512,
		BaseFeeConfig: bindings.LibSharedDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			SharingPctg:            75,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 600_000_000,
		},
	}
	MainnetProtocolConfig = &bindings.TaikoDataConfig{
		ChainId:               params.TaikoMainnetNetworkID.Uint64(),
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   360_000,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		OntakeForkHeight:      538_304,
		BaseFeeConfig: bindings.LibSharedDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			SharingPctg:            75,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 600_000_000,
		},
	}
)

// GetProtocolConfig returns the protocol config for the given chain ID.
func GetProtocolConfig(chainID uint64) *bindings.TaikoDataConfig {
	switch chainID {
	case params.HeklaNetworkID.Uint64():
		return HeklaProtocolConfig
	case params.TaikoMainnetNetworkID.Uint64():
		return MainnetProtocolConfig
	default:
		return InternlDevnetProtocolConfig
	}
}

// EncodeBaseFeeConfig encodes the block.extraData field from the given base fee config.
func EncodeBaseFeeConfig(baseFeeConfig *bindings.LibSharedDataBaseFeeConfig) [32]byte {
	var (
		bytes32Value [32]byte
		uintValue    = new(big.Int).SetUint64(uint64(baseFeeConfig.SharingPctg))
	)
	copy(bytes32Value[32-len(uintValue.Bytes()):], uintValue.Bytes())
	return bytes32Value
}
