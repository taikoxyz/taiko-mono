package message

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

func (p *Processor) estimateGas(
	ctx context.Context, message bridge.IBridgeMessage, proof []byte) (uint64, *big.Int, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, message.DestChainId)
	if err != nil {
		return 0, nil, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.NoSend = true

	auth.Context = ctx

	// estimate gas with auth.NoSend set to true
	tx, err := p.destBridge.ProcessMessage(auth, message, proof)
	if err != nil {
		return 0, nil, errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	return tx.Gas(), tx.Cost(), nil
}
