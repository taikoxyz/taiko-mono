package message

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (p *Processor) waitForConfirmations(ctx context.Context, txHash common.Hash, blockNumber uint64) error {
	ctx, cancelFunc := context.WithTimeout(ctx, time.Duration(p.confTimeoutInSeconds)*time.Second)

	defer cancelFunc()

	if err := relayer.WaitConfirmations(
		ctx,
		p.srcEthClient,
		p.confirmations,
		txHash,
	); err != nil {
		return errors.Wrap(err, "relayer.WaitConfirmations")
	}

	return nil
}
