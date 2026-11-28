package relayer

import "math/big"

// PaddedMessageGasLimit returns the relayer gas limit after applying recipient padding.
func PaddedMessageGasLimit(messageGasLimit uint64, isContractRecipient bool) uint64 {
	multiplier := uint64(105)
	if isContractRecipient {
		multiplier = 110
	}

	return (messageGasLimit*multiplier + 99) / 100
}

// ProcessMessageGasLimit returns the gas limit for a processMessage transaction: the padded
// message gas limit, raised to the destination chain's gas estimate plus 10% when that is
// higher. Forks that reprice state, such as Amsterdam (EIP-8037), can make processing cost
// more than the message gas limit budgets for. The padded limit stays the floor because a
// minimal estimate can starve the message invocation without reverting the transaction.
func ProcessMessageGasLimit(paddedGasLimit, estimatedGas uint64) uint64 {
	bufferedEstimate := (estimatedGas*110 + 99) / 100
	if bufferedEstimate > paddedGasLimit {
		return bufferedEstimate
	}

	return paddedGasLimit
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
