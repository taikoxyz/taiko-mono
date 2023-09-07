package indexer

import (
	"context"
	"log/slog"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/pkg/errors"
)

func (indxr *Indexer) indexRawBlockData(
	ctx context.Context,
	chainID *big.Int,
	start uint64,
	end uint64,
) error {
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(start)),
		ToBlock:   big.NewInt(int64(end)),
	}

	logs, err := indxr.ethClient.FilterLogs(ctx, query)
	if err != nil {
		return err
	}

	// BLOCK parsing
	for i := start; i < end; i++ {
		block, err := indxr.ethClient.BlockByNumber(ctx, big.NewInt(int64(i)))
		if err != nil {
			return errors.Wrap(err, "indxr.ethClient.BlockByNumber")
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

			if err := indxr.txRepo.Save(ctx, tx, sender, block.Number(), time.Unix(int64(block.Time()), 0)); err != nil {
				return err
			}
		}
	}

	// LOGS parsing

	// index NFT transfers
	if indxr.indexNfts {
		if err := indxr.indexNFTTransfers(ctx, chainID, logs); err != nil {
			return errors.Wrap(err, "svc.indexNFTTransfers")
		}
		return nil
	}

	return nil
}
