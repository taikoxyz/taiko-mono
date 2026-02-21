package http

import (
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetCost_LayerBehaviour(t *testing.T) {
	srv := &Server{processingFeeMultiplier: 2.5}

	gasLimit := uint64(10)
	gasTipCap := big.NewInt(1)
	baseFee := big.NewInt(2)

	// Calculate base cost used by both branches: gasLimit * (gasTipCap + baseFee*2).
	baseCost := new(big.Int).Mul(
		new(big.Int).SetUint64(gasLimit),
		new(big.Int).Add(gasTipCap, new(big.Int).Mul(baseFee, big.NewInt(2))),
	)

	gotLayer2 := srv.getCost(gasLimit, gasTipCap, baseFee, Layer2)
	gotLayer1 := srv.getCost(gasLimit, gasTipCap, baseFee, Layer1)

	// For Layer2 we expect raw base cost without processingFeeMultiplier.
	assert.Equal(t, baseCost, gotLayer2)

	// For Layer1 we expect base cost multiplied by processingFeeMultiplier.
	costRat := new(big.Rat).SetInt(baseCost)
	multiplierRat := new(big.Rat).SetFloat64(srv.processingFeeMultiplier)
	costRat.Mul(costRat, multiplierRat)
	expectedLayer1 := new(big.Int).Div(costRat.Num(), costRat.Denom())

	assert.Equal(t, expectedLayer1, gotLayer1)
}
