package message

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (p *Processor) waitForConfirmations(ctx context.Context, txHash common.Hash, blockNumber uint64) error {
	// TODO: make timeout a config var
	ctx, cancelFunc := context.WithTimeout(ctx, 5*time.Minute)

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
