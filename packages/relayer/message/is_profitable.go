package message

import (
	"context"
	"math/big"

	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

func (p *Processor) isProfitable(
	ctx context.Context, message bridge.IBridgeMessage, cost *big.Int) (bool, error) {
	processingFee := message.ProcessingFee

	if processingFee == nil || processingFee.Cmp(big.NewInt(0)) != 1 {
		return false, nil
	}

	shouldProcess := processingFee.Cmp(cost) == 1

	log.Infof(
		"processingFee: %v, cost: %v, process: %v",
		processingFee.Uint64(),
		cost,
		shouldProcess,
	)

	if !shouldProcess {
		return false, nil
	}

	return true, nil
}
