package message

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
)

func (p *Processor) isProfitable(ctx context.Context, message contracts.IBridgeMessage, proof []byte) (bool, error) {
	processingFee := message.ProcessingFee

	if processingFee == nil || processingFee.Cmp(big.NewInt(0)) != 1 {
		return false, nil
	}

	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, message.DestChainId)
	if err != nil {
		return false, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.NoSend = true

	auth.Context = ctx

	// process the message on the destination bridge.
	tx, err := p.destBridge.ProcessMessage(auth, message, proof)
	if err != nil {
		return false, errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	cost := tx.Cost()

	if processingFee.Cmp(cost) != 1 {
		return false, nil
	}

	return true, nil
}
