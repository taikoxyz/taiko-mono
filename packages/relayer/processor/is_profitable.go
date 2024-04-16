package processor

import (
	"context"
	"math/big"

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
) (bool, error) {
	processingFee := message.Fee

	gasLimit := message.GasLimit

	var shouldProcess bool = false

	if processingFee == nil ||
		processingFee.Cmp(big.NewInt(0)) != 1 ||
		gasLimit == nil ||
		message.GasLimit.Cmp(big.NewInt(0)) != 1 {
		return shouldProcess, nil
	}

	res := destChainBaseFee * gasLimit.Uint64()
	if processingFee.Uint64() > res {
		shouldProcess = true
	}

	slog.Info("isProfitable",
		"processingFee", processingFee.Uint64(),
		"destChainBaseFee", destChainBaseFee,
		"messageGasLimit", message.GasLimit.Uint64(),
		"shouldProcess", shouldProcess,
		"result", res,
	)

	if !shouldProcess {
		relayer.UnprofitableMessagesDetected.Inc()

		return false, nil
	}

	return true, nil
}
