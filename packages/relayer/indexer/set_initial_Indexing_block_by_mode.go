package indexer

import (
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// setInitialIndexingBlockByMode takes in a SyncMode and determines how we should
// start our indexing
func (i *Indexer) setInitialIndexingBlockByMode(
	mode SyncMode,
	chainID *big.Int,
) error {
	startingBlock, err := i.getShastaGenesisBlockHeight()
	if err != nil {
		return err
	}

	switch mode {
	case Sync:
		// get most recently processed block height from the DB
		latest, err := i.eventRepo.FindLatestBlockID(
			i.ctx,
			i.eventName,
			chainID.Uint64(),
			i.destChainId.Uint64(),
		)
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.FindLatestBlockID")
		}

		if latest != 0 {
			startingBlock = latest - 1
		}
	case Resync:
	default:
		return relayer.ErrInvalidMode
	}

	i.latestIndexedBlockNumber = startingBlock

	return nil
}

// getShastaGenesisBlockHeight returns the Shasta genesis block height using the
// inbox contract. Returns 0 if no inbox contract is configured.
func (i *Indexer) getShastaGenesisBlockHeight() (uint64, error) {
	if i.shastaInbox == nil {
		return 0, nil
	}

	ts, err := i.shastaInbox.ActivationTimestamp(nil)
	if err != nil {
		return 0, errors.Wrap(err, "shastaInbox.ActivationTimestamp")
	}

	blockNum, err := i.getBlockByTimestamp(i.ctx, ts.Uint64())
	if err != nil {
		return 0, errors.Wrap(err, "getBlockByTimestamp")
	}

	return blockNum, nil
}
