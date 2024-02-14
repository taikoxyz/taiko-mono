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

func (indxr *Indexer) indexRawBlockData(
	ctx context.Context,
	chainID *big.Int,
	start uint64,
	end uint64,
) error {
	wg, ctx := errgroup.WithContext(ctx)
	// BLOCK parsing

	slog.Info("indexRawBlockData", "start", start, "end", end)

	// only index block/transaction data on L2
	if indxr.layer == Layer2 {
		for i := start; i < end; i++ {
			id := i

			wg.Go(func() error {
				slog.Info("processing block data", "blockNum", id)

				block, err := indxr.ethClient.BlockByNumber(ctx, big.NewInt(int64(id)))

				if err != nil {
					return errors.Wrap(err, "indxr.ethClient.BlockByNumber")
				}

				if err := indxr.blockRepo.Save(ctx, block, chainID); err != nil {
					return errors.Wrap(err, "indxr.blockRepo.Save")
				}

				txs := block.Transactions()

				for _, tx := range txs {
					slog.Info("transaction found", "hash", tx.Hash())
					receipt, err := indxr.ethClient.TransactionReceipt(ctx, tx.Hash())

					if err != nil {
						return err
					}

					sender, err := indxr.ethClient.TransactionSender(ctx, tx, block.Hash(), receipt.TransactionIndex)
					if err != nil {
						return err
					}

					if err := indxr.accountRepo.Save(ctx, sender, time.Unix(int64(block.Time()), 0)); err != nil {
						return err
					}

					if err := indxr.txRepo.Save(ctx,
						tx,
						sender,
						block.Number(),
						time.Unix(int64(block.Time()), 0),
						receipt.ContractAddress,
					); err != nil {
						return err
					}
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

	logs, err := indxr.ethClient.FilterLogs(ctx, query)
	if err != nil {
		return err
	}

	// index NFT transfers
	if indxr.indexNfts {
		wg.Go(func() error {
			if err := indxr.indexNFTTransfers(ctx, chainID, logs); err != nil {
				return errors.Wrap(err, "svc.indexNFTTransfers")
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
