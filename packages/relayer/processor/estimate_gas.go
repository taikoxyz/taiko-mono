package processor

import (
	"context"
	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

var (
	gasPaddingAmt uint64 = 80000
)

func (p *Processor) estimateGas(
	ctx context.Context, message bridge.IBridgeMessage, proof []byte) (uint64, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, message.DestChainId)
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

	slog.Info("estimated gas", "gas", tx.Gas(), "paddingAmt", gasPaddingAmt)

	return tx.Gas() + gasPaddingAmt, nil
}
