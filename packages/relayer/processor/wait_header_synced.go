package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// maxCheckpointAge is how many blocks behind the source chain's head the checkpoint a proof is
// built at may be when checkpoint reveal is enabled. A path-scheme geth without trie-node history
// serves eth_getProof only for about the latest 128 blocks; the margin covers anchor lag and the
// time until the proof is generated.
const maxCheckpointAge = 96

// waitHeaderSynced waits for a CheckpointSaved event to appear in the database
// from the indexer that is greater or equal to the given blockNum.
// This is used to make sure a valid proof can be generated and verified on chain.
// With checkpoint reveal enabled, the checkpoint must also be recent: no more than
// maxCheckpointAge blocks behind the source chain's head (see requiredCheckpoint).
// While it waits, such a processor asks for a checkpoint that is recent enough,
// since after the Etna fork no anchor transaction saves it.
func (p *Processor) waitHeaderSynced(
	ctx context.Context,
	ethClient ethClient,
	hopChainId uint64,
	blockNum uint64,
) (*relayer.Event, error) {
	chainId, err := ethClient.ChainID(ctx)
	if err != nil {
		return nil, err
	}

	required, err := p.requiredCheckpoint(ctx, ethClient, blockNum)
	if err != nil {
		return nil, err
	}

	event, err := p.eventRepo.CheckpointSyncedEventByBlockNumberOrGreater(ctx, hopChainId, chainId.Uint64(), required)
	if err != nil {
		return nil, err
	}

	if event != nil {
		slog.Info("checkpointSynced done",
			"syncedBlockID", event.BlockID,
			"blockIDWaitingFor", blockNum,
			"requiredBlockID", required,
		)

		return event, nil
	}

	p.tryRevealCheckpoint(ctx, required)

	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			// The head moves while the message waits. When it cannot be read, the last required block
			// stays: falling back to blockNum would accept the stale checkpoint this check avoids.
			if latest, err := p.requiredCheckpoint(ctx, ethClient, blockNum); err != nil {
				slog.Warn("Failed to read the L1 head, keeping the required checkpoint",
					"blockIDWaitingFor", blockNum,
					"requiredBlockID", required,
					"error", err,
				)
			} else {
				required = latest
			}

			event, err := p.eventRepo.CheckpointSyncedEventByBlockNumberOrGreater(ctx, hopChainId, chainId.Uint64(), required)
			if err != nil {
				return nil, err
			}

			if event != nil {
				slog.Info("checkpointSynced done",
					"syncedBlockID", event.BlockID,
					"blockIDWaitingFor", blockNum,
					"requiredBlockID", required,
				)

				return event, nil
			}

			p.tryRevealCheckpoint(ctx, required)
		}
	}
}

// requiredCheckpoint returns the lowest source block whose checkpoint can prove a message from
// blockNum. Without checkpoint reveal that is blockNum, and the source chain is not read. With it,
// the checkpoint must also be at most maxCheckpointAge blocks behind the source head: after Etna
// nothing keeps the newest indexed checkpoint fresh, so a message processed late, such as an
// unprofitable retry, would otherwise be proven at a block the L1 node no longer has state for.
func (p *Processor) requiredCheckpoint(ctx context.Context, ethClient ethClient, blockNum uint64) (uint64, error) {
	if p.checkpointRevealer == nil {
		return blockNum, nil
	}

	head, err := ethClient.BlockNumber(ctx)
	if err != nil {
		return 0, err
	}

	if head > maxCheckpointAge {
		return max(blockNum, head-maxCheckpointAge), nil
	}

	return blockNum, nil
}

// tryRevealCheckpoint asks the checkpoint revealer, when there is one, for a checkpoint covering
// blockNum. A failed reveal is logged and counted but never fails the wait: the message keeps
// waiting, and a later attempt may succeed. Failures caused by the processor shutting down are not
// counted.
func (p *Processor) tryRevealCheckpoint(ctx context.Context, blockNum uint64) {
	if p.checkpointRevealer == nil {
		return
	}

	if err := p.checkpointRevealer.reveal(ctx, blockNum); err != nil {
		if ctx.Err() != nil {
			return
		}

		relayer.CheckpointRevealErrors.Inc()

		slog.Warn("Failed to reveal an L1 checkpoint",
			"blockIDWaitingFor", blockNum,
			"error", err,
		)
	}
}
