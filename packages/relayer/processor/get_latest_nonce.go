package processor

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
)

// getLatestNonce will return the latest nonce on chain if its higher than
// the one locally stored in the processor, then set it on the auth struct.
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
