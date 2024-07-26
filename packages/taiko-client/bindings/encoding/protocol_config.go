package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

var (
	livenessBond, _             = new(big.Int).SetString("125000000000000000000", 10)
	InternlDevnetProtocolConfig = &bindings.TaikoDataConfig{
		ChainId:                   params.TaikoInternalL2ANetworkID.Uint64(),
		BlockMaxProposals:         324_000,
		BlockRingBufferSize:       360_000,
		MaxBlocksToVerify:         16,
		BlockMaxGasLimit:          240_000_000,
		LivenessBond:              livenessBond,
		StateRootSyncInternal:     16,
		MaxAnchorHeightOffset:     64,
		BasefeeAdjustmentQuotient: 8,
		BasefeeSharingPctg:        75,
		BlockGasIssuance:          20_000_000,
		OntakeForkHeight:          374_400,
	}
	HeklaProtocolConfig = &bindings.TaikoDataConfig{
		ChainId:                   params.HeklaNetworkID.Uint64(),
		BlockMaxProposals:         324_000,
		BlockRingBufferSize:       324_512,
		MaxBlocksToVerify:         16,
		BlockMaxGasLimit:          240_000_000,
		LivenessBond:              livenessBond,
		StateRootSyncInternal:     16,
		MaxAnchorHeightOffset:     64,
		BasefeeAdjustmentQuotient: 8,
		BasefeeSharingPctg:        75,
		BlockGasIssuance:          20_000_000,
		OntakeForkHeight:          540_000,
	}
	MainnetProtocolConfig = &bindings.TaikoDataConfig{
		ChainId:                   params.TaikoMainnetNetworkID.Uint64(),
		BlockMaxProposals:         324_000,
		BlockRingBufferSize:       360_000,
		MaxBlocksToVerify:         16,
		BlockMaxGasLimit:          240_000_000,
		LivenessBond:              livenessBond,
		StateRootSyncInternal:     16,
		MaxAnchorHeightOffset:     64,
		BasefeeAdjustmentQuotient: 8,
		BasefeeSharingPctg:        75,
		BlockGasIssuance:          20_000_000,
		OntakeForkHeight:          374_400,
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
