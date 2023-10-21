package processor

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

func (p *Processor) isProfitable(
	ctx context.Context, message bridge.IBridgeMessage, cost *big.Int) (bool, error) {
	processingFee := message.Fee

	if processingFee == nil || processingFee.Cmp(big.NewInt(0)) != 1 {
		return false, nil
	}

	shouldProcess := processingFee.Cmp(cost) == 1

	slog.Info("isProfitable",
		"processingFee", processingFee.Uint64(),
		"cost", cost,
		"shouldProcess", shouldProcess,
	)

	if !shouldProcess {
		return false, nil
	}

	return true, nil
}
