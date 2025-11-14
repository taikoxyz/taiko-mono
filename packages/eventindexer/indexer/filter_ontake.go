package indexer

import (
	"context"
	"log/slog"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"golang.org/x/sync/errgroup"
)

func filterFuncOntake(
	ctx context.Context,
	chainID *big.Int,
	i *Indexer,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	if i.taikol1 != nil {
		wg.Go(func() error {
			transitionProvedEvents, err := i.taikol1.FilterTransitionProvedV2(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterTransitionProvedV2")
			}

			err = i.saveTransitionProvedEventsV2(ctx, chainID, transitionProvedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveTransitionProvedEventsV2")
			}

			return nil
		})

		wg.Go(func() error {
			transitionContestedEvents, err := i.taikol1.FilterTransitionContestedV2(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterTransitionContestedV2")
			}

			err = i.saveTransitionContestedEventsV2(ctx, chainID, transitionContestedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveTransitionContestedEventsV2")
			}

			return nil
		})

		wg.Go(func() error {
			blockProposedEvents, err := i.taikol1.FilterBlockProposedV2(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterBlockProposedV2")
			}

			err = i.saveBlockProposedEventsV2(ctx, chainID, blockProposedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveBlockProposedEventsV2")
			}

			return nil
		})

		wg.Go(func() error {
			blockVerifiedEvents, err := i.taikol1.FilterBlockVerifiedV2(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterBlockVerifiedV2")
			}

			err = i.saveBlockVerifiedEventsV2(ctx, chainID, blockVerifiedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveBlockVerifiedEventsV2")
			}

			return nil
		})
	}

	if i.bridge != nil {
		wg.Go(func() error {
			messagesSent, err := i.bridge.FilterMessageSent(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.bridge.FilterMessageSent")
			}

			err = i.saveMessageSentEvents(ctx, chainID, messagesSent)
			if err != nil {
				return errors.Wrap(err, "i.saveMessageSentEvents")
			}

			return nil
		})
	}

	wg.Go(func() error {
		if err := i.indexRawBlockData(ctx, chainID, filterOpts.Start, *filterOpts.End); err != nil {
			return errors.Wrap(err, "i.indexRawBlockData")
		}

		return nil
	})

	err := wg.Wait()

	if err != nil {
		if errors.Is(err, context.Canceled) {
			slog.Error("filter context cancelled")
			return err
		}

		return err
	}

	return nil
}
