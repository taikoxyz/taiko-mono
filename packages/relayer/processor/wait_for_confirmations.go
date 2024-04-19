package processor

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// waitForConfirmations waits for the given transaction to reach N confs
// before returning
func (p *Processor) waitForConfirmations(ctx context.Context, txHash common.Hash, blockNumber uint64) error {
	ctx, cancelFunc := context.WithTimeout(ctx, time.Duration(p.confTimeoutInSeconds)*time.Second)

	defer cancelFunc()

	if err := relayer.WaitConfirmations(
		ctx,
		p.srcEthClient,
		p.confirmations,
		txHash,
	); err != nil {
		return err
	}

	return nil
}
