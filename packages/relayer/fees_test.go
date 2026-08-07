package relayer

import (
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPaddedMessageGasLimit(t *testing.T) {
	assert.Equal(t, uint64(846990), PaddedMessageGasLimit(806657, false))
	assert.Equal(t, uint64(1446896), PaddedMessageGasLimit(1315360, true))
}

func TestEffectiveGasTipCap(t *testing.T) {
	// A suggested tip below the minimum is raised to the minimum, matching how
	// the tx manager floors the tip before sending. This is the case that caused
	// false "unprofitable after transacting" events on L2, where the suggested
	// tip (~0.003 gwei) sits below the 0.01 gwei MinTipCap the tx manager pays.
	assert.Equal(t,
		big.NewInt(10_000_000),
		EffectiveGasTipCap(big.NewInt(3_461_844), big.NewInt(10_000_000)),
	)

	// A suggested tip above the minimum is used unchanged.
	assert.Equal(t,
		big.NewInt(2_000_000_000),
		EffectiveGasTipCap(big.NewInt(2_000_000_000), big.NewInt(1_000_000_000)),
	)

	// A suggested tip equal to the minimum is used unchanged.
	assert.Equal(t,
		big.NewInt(1_000_000_000),
		EffectiveGasTipCap(big.NewInt(1_000_000_000), big.NewInt(1_000_000_000)),
	)

	// A nil minimum applies no floor (e.g. when no tx manager config is set).
	assert.Equal(t,
		big.NewInt(5),
		EffectiveGasTipCap(big.NewInt(5), nil),
	)
}
