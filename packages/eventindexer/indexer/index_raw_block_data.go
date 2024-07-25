package indexer

import (
	"context"
	"log/slog"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/pkg/errors"
	"golang.org/x/sync/errgroup"
)

func (i *Indexer) indexRawBlockData(
	ctx context.Context,
	chainID *big.Int,
	start uint64,
	end uint64,
) error {
	wg, ctx := errgroup.WithContext(ctx)
	// BLOCK parsing

	slog.Info("indexRawBlockData", "start", start, "end", end)

	// only index block/transaction data on L2
	if i.layer == Layer2 {
		for j := start; j <= end; j++ {
			id := j

			wg.Go(func() error {
				slog.Info("processing block data", "blockNum", id)

				block, err := i.ethClient.BlockByNumber(ctx, big.NewInt(int64(id)))

				if err != nil {
					return errors.Wrap(err, "i.ethClient.BlockByNumber")
				}

				txs := block.Transactions()

				txWg, ctx := errgroup.WithContext(ctx)

				for _, tx := range txs {
					t := tx

					txWg.Go(func() error {
						slog.Info("transaction found", "hash", t.Hash())

						receipt, err := i.ethClient.TransactionReceipt(ctx, t.Hash())

						if err != nil {
							return errors.Wrap(err, "i.ethClient.TransactionReceipt")
						}

						sender, err := i.ethClient.TransactionSender(ctx, t, block.Hash(), receipt.TransactionIndex)
						if err != nil {
							return errors.Wrap(err, "i.ethClient.TransactionSender")
						}

						if err := i.accountRepo.Save(ctx, sender, time.Unix(int64(block.Time()), 0)); err != nil {
							return errors.Wrap(err, "i.accountRepo.Save")
						}

						if err := i.txRepo.Save(ctx,
							t,
							sender,
							block.Number(),
							time.Unix(int64(block.Time()), 0),
							receipt.ContractAddress,
						); err != nil {
							return errors.Wrap(err, "i.txRepo.Save")
						}

						return nil
					})
				}

				if err := txWg.Wait(); err != nil {
					return err
				}

				return nil
			})
		}
	}

	// LOGS parsing
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(start)),
		ToBlock:   big.NewInt(int64(end)),
	}

	logs, err := i.ethClient.FilterLogs(ctx, query)
	if err != nil {
		return err
	}

	// index NFT transfers
	if i.indexNfts {
		wg.Go(func() error {
			if err := i.indexNFTTransfers(ctx, chainID, logs); err != nil {
				return errors.Wrap(err, "svc.indexNFTTransfers")
			}

			return nil
		})
	}

	if i.indexERC20s {
		wg.Go(func() error {
			if err := i.indexERC20Transfers(ctx, chainID, logs); err != nil {
				return errors.Wrap(err, "svc.indexERC20Transfers")
			}

			return nil
		})
	}

	if err := wg.Wait(); err != nil {
		if errors.Is(err, context.Canceled) {
			slog.Error("index raw block data context cancelled")
			return err
		}

		return err
	}

	return nil
}
