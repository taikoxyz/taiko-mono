package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/pkg/errors"
)

func (svc *Service) indexRawBlockData(
	ctx context.Context,
	chainID *big.Int,
	start uint64,
	end uint64,
) error {
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(start)),
		ToBlock:   big.NewInt(int64(end)),
	}

	logs, err := svc.ethClient.FilterLogs(ctx, query)
	if err != nil {
		return err
	}

	// BLOCK parsing

	for i := start; i < end; i++ {
		block, err := svc.ethClient.BlockByNumber(ctx, big.NewInt(int64(i)))
		if err != nil {
			return errors.Wrap(err, "svc.ethClient.BlockByNumber")
		}

		txs := block.Transactions()

		for _, tx := range txs {

		}
	}


	// LOGS parsing

	// index NFT transfers
	if svc.indexNfts {
		if err := svc.indexNFTTransfers(ctx, chainID, logs); err != nil {
			return errors.Wrap(err, "svc.indexNFTTransfers")
		}
		return nil
	}

	return nil
}
