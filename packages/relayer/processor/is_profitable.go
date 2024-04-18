package processor

import (
	"context"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

// isProfitable determines whether a message is profitable or not. It should
// check the processing fee, if one does not exist at all, it is definitely not
// profitable. Otherwise, we compare it to the estimated cost.
func (p *Processor) isProfitable(
	ctx context.Context,
	message bridge.IBridgeMessage,
	destChainBaseFee uint64,
	gasTipCap uint64,
) (bool, error) {
	processingFee := message.Fee

	gasLimit := message.GasLimit

	var shouldProcess bool = false

	if processingFee == 0 || gasLimit == 0 {
		slog.Info("unprofitable: no gasLimit or processingFee",
			"processingFee", processingFee,
			"gasLimit", gasLimit,
		)

		return shouldProcess, nil
	}

	// if processing fee is higher than baseFee * gasLimit,
	// we should process.
	res := (destChainBaseFee + gasTipCap) * uint64(gasLimit)
	if processingFee > res {
		shouldProcess = true
	}

	slog.Info("isProfitable",
		"processingFee", processingFee,
		"destChainBaseFee", destChainBaseFee,
		"messageGasLimit", message.GasLimit,
		"shouldProcess", shouldProcess,
		"result", res,
	)

	if !shouldProcess {
		relayer.UnprofitableMessagesDetected.Inc()

		return false, nil
	}

	return true, nil
}
