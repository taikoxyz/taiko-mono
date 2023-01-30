package message

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

func (p *Processor) isProfitable(
	ctx context.Context, message bridge.IBridgeMessage, proof []byte) (bool, uint64, error) {
	processingFee := message.ProcessingFee

	if processingFee == nil || processingFee.Cmp(big.NewInt(0)) != 1 {
		return false, 0, nil
	}

	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, message.DestChainId)
	if err != nil {
		return false, 0, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.NoSend = true

	auth.Context = ctx

	// estimate gas with auth.NoSend set to true
	tx, err := p.destBridge.ProcessMessage(auth, message, proof)
	if err != nil {
		return false, 0, errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	cost := tx.Cost()

	shouldProcess := processingFee.Cmp(cost) == 1

	log.Infof(
		"processingFee: %v, cost: %v, process: %v",
		processingFee.Uint64(),
		cost,
		shouldProcess,
	)

	if !shouldProcess {
		return false, 0, nil
	}

	return true, tx.Gas(), nil
}
