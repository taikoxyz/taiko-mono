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
	startingBlock, err := i.getGenesisBlockHeight()
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

// getGenesisBlockHeight returns the genesis block height by trying different
// contract versions in order (v1 -> v2 -> v3 -> v4). Returns 0 if no TaikoL1
// contract is configured.
func (i *Indexer) getGenesisBlockHeight() (uint64, error) {
	if i.taikol1 == nil {
		return 0, nil
	}

	// Try v1 bindings
	slotA, _, err := i.taikol1.GetStateVariables(nil)
	if err == nil {
		return slotA.GenesisHeight - 1, nil
	}

	// Try v2 bindings
	slotAV2, _, err := i.taikoL1V2.GetStateVariables(nil)
	if err == nil {
		return slotAV2.GenesisHeight - 1, nil
	}

	// Try v3 bindings
	stats, err := i.taikoInboxV3.GetStats1(nil)
	if err == nil {
		return stats.GenesisHeight - 1, nil
	}

	// Try v4 bindings
	if i.shastaInbox == nil {
		return 0, errors.New("no compatible TaikoL1 contract version found")
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
