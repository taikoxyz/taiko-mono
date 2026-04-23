package manifest

import (
	"math"
	"math/big"

	"github.com/ethereum/go-ethereum/params"
)

// Unzen fork activation timestamps per Taiko L2 chain. math.MaxUint64 means never.
const (
	// DevnetUnzenTime is the Unzen activation timestamp on Taiko internal devnet.
	// 0 means active from genesis (mirrors Rust UNZEN_FORK_DEVNET).
	DevnetUnzenTime uint64 = 0
	// MasayaUnzenTime is the Unzen activation timestamp on Taiko Masaya. Not yet scheduled.
	MasayaUnzenTime uint64 = math.MaxUint64
	// HoodiUnzenTime is the Unzen activation timestamp on Taiko Hoodi. Not yet scheduled.
	HoodiUnzenTime uint64 = math.MaxUint64
	// MainnetUnzenTime is the Unzen activation timestamp on Taiko Mainnet. Not yet scheduled.
	MainnetUnzenTime uint64 = math.MaxUint64
)

// UnzenActivationTime returns the Unzen fork activation timestamp for a Taiko L2 chain.
// Returns math.MaxUint64 for unknown chains or when Unzen is not scheduled.
func UnzenActivationTime(chainID *big.Int) uint64 {
	if chainID == nil {
		return math.MaxUint64
	}

	switch chainID.Uint64() {
	case params.TaikoInternalNetworkID.Uint64():
		return DevnetUnzenTime
	case params.MasayaDevnetNetworkID.Uint64():
		return MasayaUnzenTime
	case params.TaikoHoodiNetworkID.Uint64():
		return HoodiUnzenTime
	case params.TaikoMainnetNetworkID.Uint64():
		return MainnetUnzenTime
	default:
		return math.MaxUint64
	}
}

// IsUnzen returns whether the given chain and timestamp are inside the Unzen fork.
func IsUnzen(chainID *big.Int, timestamp uint64) bool {
	activation := UnzenActivationTime(chainID)
	return activation != math.MaxUint64 && timestamp >= activation
}
