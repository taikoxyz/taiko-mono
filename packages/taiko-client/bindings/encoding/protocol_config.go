package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/params"

	v2 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v2"
)

var (
	livenessBond, _             = new(big.Int).SetString("125000000000000000000", 10)
	InternlDevnetProtocolConfig = &v2.TaikoDataConfig{
		ChainId:               params.TaikoInternalL2ANetworkID.Uint64(),
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   360_000,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		BaseFeeConfig: v2.TaikoDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 600000000,
		},
	}
	PreconfsDevnetProtocolConfig = &v2.TaikoDataConfig{
		ChainId:               167010,
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   360_000,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		BaseFeeConfig: v2.TaikoDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 600000000,
		},
	}
	HeklaProtocolConfig = &v2.TaikoDataConfig{
		ChainId:               params.HeklaNetworkID.Uint64(),
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   324_512,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		BaseFeeConfig: v2.TaikoDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 500000000,
		},
	}
	MainnetProtocolConfig = &v2.TaikoDataConfig{
		ChainId:               params.TaikoMainnetNetworkID.Uint64(),
		BlockMaxProposals:     324_000,
		BlockRingBufferSize:   360_000,
		MaxBlocksToVerify:     16,
		BlockMaxGasLimit:      240_000_000,
		LivenessBond:          livenessBond,
		StateRootSyncInternal: 16,
		MaxAnchorHeightOffset: 64,
		BaseFeeConfig: v2.TaikoDataBaseFeeConfig{
			AdjustmentQuotient:     8,
			GasIssuancePerSecond:   5_000_000,
			MinGasExcess:           1_340_000_000,
			MaxGasIssuancePerBlock: 500000000,
		},
	}
)

// GetProtocolConfig returns the protocol config for the given chain ID.
func GetProtocolConfig(chainID uint64) *v2.TaikoDataConfig {
	switch chainID {
	case params.HeklaNetworkID.Uint64():
		return HeklaProtocolConfig
	case params.TaikoMainnetNetworkID.Uint64():
		return MainnetProtocolConfig
	case 167010:
		return PreconfsDevnetProtocolConfig
	default:
		return InternlDevnetProtocolConfig
	}
}
