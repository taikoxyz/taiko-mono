package processor

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

var (
	gasPaddingAmt uint64 = 80000
)

// estimateGas estimates the gas for a ProcessMessage call. It will add a gasPaddingAmt
// in case, because the amount of exact gas is hard to predict due to proof verification
// on chain.
func (p *Processor) estimateGas(
	ctx context.Context, message bridge.IBridgeMessage, proof []byte) (uint64, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, new(big.Int).SetUint64(message.DestChainId))
	if err != nil {
		return 0, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.NoSend = true

	auth.Context = ctx

	// estimate gas with auth.NoSend set to true
	tx, err := p.destBridge.ProcessMessage(auth, message, proof)
	if err != nil {
		return 0, errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	return tx.Gas() + gasPaddingAmt, nil
}
