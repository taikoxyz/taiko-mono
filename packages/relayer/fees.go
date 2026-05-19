package relayer

// PaddedMessageGasLimit returns the relayer gas limit after applying recipient padding.
func PaddedMessageGasLimit(messageGasLimit uint64, isContractRecipient bool) uint64 {
	multiplier := uint64(105)
	if isContractRecipient {
		multiplier = 110
	}

	return (messageGasLimit*multiplier + 99) / 100
}
