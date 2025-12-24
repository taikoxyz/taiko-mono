package handler

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// isBatchVerified checks whether the given L2 block has been verified.
func isBatchVerified(ctx context.Context, rpc *rpc.Client, id *big.Int) (bool, error) {
	lastVerifiedTransition, err := rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		return false, err
	}

	return id.Uint64() <= lastVerifiedTransition.BatchId, nil
}

// getMetadataFromBatchPacaya fetches the batch meta from the onchain event by the given batch id.
func getMetadataFromBatchPacaya(
	ctx context.Context,
	rpc *rpc.Client,
	batch *pacaya.ITaikoInboxBatch,
) (m metadata.TaikoProposalMetaData, err error) {
	callback := func(
		_ context.Context,
		meta metadata.TaikoProposalMetaData,
		_ eventIterator.EndBatchProposedEventIterFunc,
	) error {
		if !meta.IsPacaya() {
			return nil
		}
		// Only filter for exact batchID we want.
		if meta.Pacaya().GetBatchID().Cmp(new(big.Int).SetUint64(batch.BatchId)) != 0 {
			return nil
		}

		m = meta

		return nil
	}

	config, err := rpc.GetProtocolConfigs(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get Pacaya protocol configs: %w", err)
	}

	// Ensure we don't go beyond the current L1 head.
	l1Head, err := rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L1 head: %w", err)
	}
	endHeight := new(big.Int).Add(
		new(big.Int).SetUint64(batch.AnchorBlockId),
		new(big.Int).SetUint64(config.MaxAnchorHeightOffset()),
	)
	if endHeight.Cmp(l1Head.Number) > 0 {
		endHeight = l1Head.Number
	}

	iter, err := eventIterator.NewBatchProposedIterator(ctx, &eventIterator.BatchProposedIteratorConfig{
		RpcClient:            rpc,
		StartHeight:          new(big.Int).SetUint64(batch.AnchorBlockId),
		EndHeight:            endHeight,
		OnBatchProposedEvent: callback,
	})
	if err != nil {
		log.Error("Failed to start event iterator", "event", "BatchProposed", "error", err)
		return nil, err
	}

	if err := iter.Iter(); err != nil {
		return nil, err
	}

	if m == nil {
		return nil, fmt.Errorf("failed to find BatchProposed event for batch %d", batch.BatchId)
	}

	return m, nil
}

// IsProvingWindowExpired returns true as the first return parameter if the assigned prover
// proving window of the given proposed block is expired, the second return parameter is the expired time,
// and the third return parameter is the time remaining till proving window is expired.
func IsProvingWindowExpired(
	rpc *rpc.Client,
	metadata metadata.TaikoProposalMetaData,
) (bool, time.Time, time.Duration, error) {
	var (
		provingWindow time.Duration
		timestamp     uint64
		err           error
	)
	protocolConfigs, err := rpc.GetProtocolConfigs(nil)
	if err != nil {
		return false, time.Time{}, 0, fmt.Errorf("failed to get Pacaya protocol configs: %w", err)
	}
	if provingWindow, err = protocolConfigs.ProvingWindow(); err != nil {
		return false, time.Time{}, 0, fmt.Errorf("failed to get Pacaya proving window: %w", err)
	}
	timestamp = metadata.Pacaya().GetProposedAt()

	var (
		now       = uint64(time.Now().Unix())
		expiredAt = timestamp + uint64(provingWindow.Seconds())
	)
	remainingSeconds := int64(expiredAt) - int64(now)
	if remainingSeconds < 0 {
		remainingSeconds = 0
	}
	return now > expiredAt, time.Unix(int64(expiredAt), 0), time.Duration(remainingSeconds) * time.Second, nil
}

// IsProvingWindowExpiredShasta returns true as the first return parameter if the assigned prover
// proving window of the given proposed block is expired, the second return parameter is the expired time,
// and the third return parameter is the time remaining till proving window is expired.
func IsProvingWindowExpiredShasta(
	rpc *rpc.Client,
	metadata metadata.TaikoProposalMetaData,
) (bool, time.Time, time.Duration, error) {
	configs, err := rpc.GetProtocolConfigsShasta(nil)
	if err != nil {
		return false, time.Time{}, 0, fmt.Errorf("failed to get Shasta protocol configs: %w", err)
	}

	var (
		now       = uint64(time.Now().Unix())
		expiredAt = metadata.Shasta().GetTimestamp() + configs.ProvingWindow.Uint64()
	)
	remainingSeconds := int64(expiredAt) - int64(now)
	if remainingSeconds < 0 {
		remainingSeconds = 0
	}
	return now > expiredAt, time.Unix(int64(expiredAt), 0), time.Duration(remainingSeconds) * time.Second, nil
}
