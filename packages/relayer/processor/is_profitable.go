package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

var (
	// errImpossible indicates that the message cannot be processed due to
	// missing or invalid basic requirements (zero fee or gas limit)
	errImpossible = errors.New("impossible to process")
)

// isProfitable determines whether processing a message would be profitable by comparing
// the processing fee with estimated transaction costs on the destination chain.
//
// Parameters:
//   - ctx: Context for the operation
//   - id: Message ID
//   - fee: Processing fee offered by the sender
//   - gasLimit: Maximum gas that can be used for processing
//   - destChainBaseFee: Current base fee on the destination chain
//   - gasTipCap: Maximum tip per gas unit willing to be paid
//
// Returns:
//   - bool: true if processing would be profitable, false otherwise
//   - error: errImpossible if basic requirements aren't met, nil otherwise
func (p *Processor) isProfitable(
	ctx context.Context,
	id int,
	fee uint64,
	gasLimit uint64,
	destChainBaseFee uint64,
	gasTipCap uint64,
) (bool, error) {
	var shouldProcess bool = false

	if fee == 0 || gasLimit == 0 {
		slog.Info("unprofitable: no gasLimit or processingFee",
			"processingFee", fee,
			"gasLimit", gasLimit,
		)

		return shouldProcess, errImpossible
	}

	// Calculate estimated on-chain cost:
	// - Base fee is multiplied by 2 to account for potential fee increases
	// - Gas tip is added to ensure transaction priority
	// - Result is multiplied by gas limit to get total cost
	estimatedOnchainFee := ((destChainBaseFee * 2) + gasTipCap) * uint64(gasLimit)
	if fee > estimatedOnchainFee {
		shouldProcess = true
	}

	slog.Info("isProfitable",
		"processingFee", fee,
		"destChainBaseFee", destChainBaseFee,
		"gasTipCap", gasTipCap,
		"gasLimit", gasLimit,
		"shouldProcess", shouldProcess,
		"estimatedOnchainFee", estimatedOnchainFee,
	)

	opts := relayer.UpdateFeesAndProfitabilityOpts{
		Fee:                     fee,
		DestChainBaseFee:        destChainBaseFee,
		GasTipCap:               gasTipCap,
		GasLimit:                gasLimit,
		IsProfitable:            shouldProcess,
		EstimatedOnchainFee:     estimatedOnchainFee,
		IsProfitableEvaluatedAt: time.Now().UTC(),
	}

	if err := p.eventRepo.UpdateFeesAndProfitability(ctx, id, &opts); err != nil {
		slog.Error("failed to update event", "error", err)
	}

	if !shouldProcess {
		relayer.UnprofitableMessagesDetected.Inc()

		return false, nil
	}

	return true, nil
}
