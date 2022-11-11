package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	sink := make(chan *contracts.BridgeMessageSent)

	sub, err := svc.bridge.WatchMessageSent(&bind.WatchOpts{}, sink, nil)
	if err != nil {
		return errors.Wrap(err, "svc.bridge.WatchMessageSent")
	}

	defer sub.Unsubscribe()

	for {
		select {
		case err := <-sub.Err():
			svc.errChan <- err
		case event := <-sink:
			go svc.handleEvent(ctx, nil, svc.errChan, chainID, event)
		}
	}
}
