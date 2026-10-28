package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/metrics"
)

// filter applies each batch serially and advances the in-memory cursor only
// after every NFT balance mutation in that batch has succeeded.
func (i *Indexer) filter(ctx context.Context) error {
	if err := i.checkWriterLock(ctx); err != nil {
		return err
	}

	endBlockID, err := i.ethClient.BlockNumber(ctx)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockNumber")
	}

	metrics.SetNFTIndexerLag(i.srcChainID, endBlockID, i.latestIndexedBlockNumber)

	for start := i.nextFilterStartBlock(); start <= endBlockID; {
		if err := i.checkWriterLock(ctx); err != nil {
			return err
		}

		if err := ctx.Err(); err != nil {
			return err
		}

		end := endBlockID
		if endBlockID-start >= i.blockBatchSize {
			end = start + i.blockBatchSize - 1
		}

		logs, err := i.ethClient.FilterLogs(ctx, ethereum.FilterQuery{
			FromBlock: new(big.Int).SetUint64(start), ToBlock: new(big.Int).SetUint64(end),
			Topics: [][]common.Hash{{logTransferSigHash, transferSingleSignatureHash, transferBatchSignatureHash}},
		})
		if err != nil {
			return errors.Wrap(err, "i.ethClient.FilterLogs")
		}

		if err := i.indexNFTTransfers(ctx, new(big.Int).SetUint64(i.srcChainID), logs); err != nil {
			return err
		}

		if err := ctx.Err(); err != nil {
			return err
		}

		if err := i.checkWriterLock(ctx); err != nil {
			return err
		}

		if err := i.nftCursorRepo.SaveCheckpoint(ctx, i.srcChainID, end); err != nil {
			return errors.Wrap(err, "save NFT checkpoint")
		}

		i.latestIndexedBlockNumber = end
		metrics.SetNFTIndexerLag(i.srcChainID, endBlockID, end)

		if end == endBlockID {
			break
		}

		start = end + 1
	}

	return nil
}

func (i *Indexer) nextFilterStartBlock() uint64 { return i.latestIndexedBlockNumber + 1 }
