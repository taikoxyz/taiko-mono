package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// etnaForkGuardSeconds is how long before the Etna fork the processor stops building legacy
// proofs. L2 picks the proof format by the claim block's timestamp, so a legacy proof whose claim
// lands after the fork reverts, and a reverted claim is dead-lettered. A send can keep
// resubmitting for five to ten minutes (see DefaultPrivateRPCSendTimeout) and the node can lag the
// chain, so the guard is ten minutes, judged by the later of the L2 head's time and the wall clock.
const etnaForkGuardSeconds = 600

// proofTarget is what a signal proof is built against. Exactly one field is set.
type proofTarget struct {
	// checkpoint is the indexed CheckpointSaved covering the message, before the Etna fork.
	checkpoint *relayer.Event
	// etna is the L1 anchor of an Etna L2 block, from the fork on.
	etna *etnaAnchor
}

// waitProofTarget waits until a proof for a message sent in source block blockNum can be built
// and verified on the destination chain.
//
// Before the Etna fork, and always on a destination without an Etna timestamp, it waits for an
// indexed CheckpointSaved event at or above blockNum. From the fork on, it waits for an Etna L2
// block whose L1 anchor covers blockNum (see etnaAnchorFor). Within etnaForkGuardSeconds before
// the fork, by the L2 head or the wall clock, it builds neither. Each round decides afresh, so a
// wait that spans the fork switches paths.
//
// It returns an error only when the context ends, the chain ID or the database fails. Errors from
// the Etna reads are logged and retried at the next round.
func (p *Processor) waitProofTarget(
	ctx context.Context,
	ethClient ethClient,
	hopChainId uint64,
	blockNum uint64,
) (*proofTarget, error) {
	chainId, err := ethClient.ChainID(ctx)
	if err != nil {
		return nil, err
	}

	target, err := p.proofTargetRound(ctx, ethClient, hopChainId, chainId.Uint64(), blockNum)
	if err != nil || target != nil {
		return target, err
	}

	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			target, err := p.proofTargetRound(ctx, ethClient, hopChainId, chainId.Uint64(), blockNum)
			if err != nil || target != nil {
				return target, err
			}
		}
	}
}

// proofTargetRound runs one round of waitProofTarget. It returns nil and no error while the proof
// has to wait.
func (p *Processor) proofTargetRound(
	ctx context.Context,
	ethClient ethClient,
	hopChainId uint64,
	chainId uint64,
	blockNum uint64,
) (*proofTarget, error) {
	etnaTimestamp, supported, err := p.etnaTimestamp(ctx)
	if err != nil {
		warnUnlessDone(ctx, "Failed to read the Etna timestamp", "error", err)

		return nil, nil
	}

	if supported {
		head, err := p.destEthClient.HeaderByNumber(ctx, nil)
		if err != nil {
			warnUnlessDone(ctx, "Failed to read the destination head", "error", err)

			return nil, nil
		}

		now := uint64(p.currentTime().Unix())

		switch {
		case max(head.Time, now)+etnaForkGuardSeconds < etnaTimestamp:
			// Before the fork, with time to land a claim: the legacy path below.
		case head.Time < etnaTimestamp:
			// Too close to the fork for a legacy proof, too early for an Etna one.
			return nil, nil
		default:
			anchor, err := p.etnaAnchorFor(ctx, ethClient, head, etnaTimestamp, blockNum)
			if err != nil {
				warnUnlessDone(ctx, "Cannot build an Etna signal proof yet",
					"blockIDWaitingFor", blockNum,
					"error", err,
				)

				return nil, nil
			}

			if anchor == nil {
				return nil, nil
			}

			slog.Info("etna anchor found",
				"l2Timestamp", anchor.l2Timestamp,
				"anchorBlockID", anchor.l1Block,
				"blockIDWaitingFor", blockNum,
			)

			return &proofTarget{etna: anchor}, nil
		}
	}

	event, err := p.eventRepo.CheckpointSyncedEventByBlockNumberOrGreater(ctx, hopChainId, chainId, blockNum)
	if err != nil {
		return nil, err
	}

	if event == nil {
		return nil, nil
	}

	slog.Info("checkpointSynced done",
		"syncedBlockID", event.BlockID,
		"blockIDWaitingFor", blockNum,
	)

	return &proofTarget{checkpoint: event}, nil
}

// warnUnlessDone logs a warning, except while the processor is shutting down: a read that fails
// because the context ended is not worth reporting, and the wait ends at the next select.
func warnUnlessDone(ctx context.Context, msg string, args ...any) {
	if ctx.Err() == nil {
		slog.Warn(msg, args...)
	}
}
