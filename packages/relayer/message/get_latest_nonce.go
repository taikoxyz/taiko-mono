package message

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
)

func (p *Processor) getLatestNonce(ctx context.Context, auth *bind.TransactOpts) error {
	pendingNonce, err := p.destEthClient.PendingNonceAt(ctx, p.relayerAddr)
	if err != nil {
		return err
	}

	if pendingNonce > p.destNonce {
		p.setLatestNonce(pendingNonce)
	}

	auth.Nonce = big.NewInt(int64(p.destNonce))

	return nil
}
