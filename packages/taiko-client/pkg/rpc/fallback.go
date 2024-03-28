package rpc

import (
	"errors"
	"math/big"
	"strings"
)

// Taken from:
// https://github.com/ethereum-optimism/optimism-legacy/blob/develop/bss-core/drivers/max_priority_fee_fallback.go
var (
	//lint:ignore ST1005 allow `errMaxPriorityFeePerGasNotFound` to be capitalized.
	errMaxPriorityFeePerGasNotFound = errors.New(
		"method eth_maxPriorityFeePerGas not found",
	)

	// FallbackGasTipCap is the default fallback gasTipCap used when we are
	// unable to query an L1 backend for a suggested gasTipCap.
	FallbackGasTipCap = big.NewInt(1500000000)
)

// IsMaxPriorityFeePerGasNotFoundError returns true if the provided error
// signals that the backend does not support the eth_maxPriorityFeePerGas
// method. In this case, the caller should fallback to using the constant above.
func IsMaxPriorityFeePerGasNotFoundError(err error) bool {
	return strings.Contains(
		err.Error(), errMaxPriorityFeePerGasNotFound.Error(),
	)
}
