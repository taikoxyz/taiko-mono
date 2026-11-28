package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/params"
)

// PaddedMessageGasLimit returns the relayer gas limit after applying recipient padding.
func PaddedMessageGasLimit(messageGasLimit uint64, isContractRecipient bool) uint64 {
	multiplier := uint64(105)
	if isContractRecipient {
		multiplier = 110
	}

	return (messageGasLimit*multiplier + 99) / 100
}

// ProcessMessageGasLimit returns the larger of the padded limit and the buffered estimate.
// The padded limit preserves invocation gas that eth_estimateGas may omit.
func ProcessMessageGasLimit(paddedGasLimit, estimatedGas uint64) uint64 {
	bufferedEstimate := (estimatedGas*110 + 99) / 100
	// Only let the buffer cross the Osaka transaction cap if the unbuffered
	// estimate already exceeds it, which is possible on Amsterdam.
	if estimatedGas <= params.MaxTxGas {
		bufferedEstimate = min(bufferedEstimate, params.MaxTxGas)
	}

	return max(paddedGasLimit, bufferedEstimate)
}

// EffectiveGasTipCap returns the gas tip cap the transaction manager will
// actually use when sending a transaction: the suggested tip, floored at the
// configured minimum tip cap. The profitability estimate must use this same
// value; otherwise it under-counts the tip whenever the suggested tip is below
// the minimum (common on L2, where the suggested tip sits near zero), which
// surfaces as false "unprofitable after transacting" events. A nil minTipCap
// applies no floor.
func EffectiveGasTipCap(suggestedTipCap, minTipCap *big.Int) *big.Int {
	if minTipCap != nil && suggestedTipCap.Cmp(minTipCap) < 0 {
		return new(big.Int).Set(minTipCap)
	}

	return suggestedTipCap
}
