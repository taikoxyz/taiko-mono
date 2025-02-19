package handler

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var (
	errTierNotFound = errors.New("tier not found")
)

// isBlockVerified checks whether the given L2 block has been verified.
func isBlockVerified(ctx context.Context, rpc *rpc.Client, id *big.Int) (bool, error) {
	lastVerifiedTransition, err := rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		lastVerifiedBlock, err := rpc.GetLastVerifiedBlockOntake(ctx)
		if err != nil {
			return false, err
		}
		return id.Uint64() <= lastVerifiedBlock.BlockId, nil
	}

	return id.Uint64() <= lastVerifiedTransition.BlockId, nil
}

// isValidProof checks if the given proof is a valid one, comparing to current L2 node canonical chain.
func isValidProof(
	ctx context.Context,
	rpc *rpc.Client,
	blockID *big.Int,
	parentHash common.Hash,
	blockHash common.Hash,
	stateRoot common.Hash,
) (bool, error) {
	parent, err := rpc.L2ParentByCurrentBlockID(ctx, blockID)
	if err != nil {
		return false, err
	}

	l2Header, err := rpc.L2.HeaderByNumber(ctx, blockID)
	if err != nil {
		return false, err
	}

	return parent.Hash() == parentHash &&
		l2Header.Hash() == blockHash &&
		l2Header.Root == stateRoot, nil
}

// getProvingWindowOntake returns the provingWindow of the given tier.
func getProvingWindowOntake(
	tier uint16,
	tiers []*rpc.TierProviderTierWithID,
) (time.Duration, error) {
	for _, t := range tiers {
		if tier == t.ID {
			return time.Duration(t.ProvingWindow) * time.Minute, nil
		}
	}

	return 0, errTierNotFound
}

// getMetadataFromBlockIDOntake fetches the block meta from the onchain event by the given block id.
func getMetadataFromBlockIDOntake(
	ctx context.Context,
	rpc *rpc.Client,
	id *big.Int,
	proposedIn *big.Int,
) (m metadata.TaikoProposalMetaData, err error) {
	callback := func(
		_ context.Context,
		meta metadata.TaikoProposalMetaData,
		_ eventIterator.EndBlockProposedEventIterFunc,
	) error {
		// Only filter for exact blockID we want.
		if meta.Ontake().GetBlockID().Cmp(id) != 0 {
			return nil
		}

		m = meta

		return nil
	}

	iter, err := eventIterator.NewBlockProposedIterator(ctx, &eventIterator.BlockProposedIteratorConfig{
		Client:               rpc.L1,
		TaikoL1:              rpc.OntakeClients.TaikoL1,
		TaikoInbox:           rpc.PacayaClients.TaikoInbox,
		PacayaForkHeight:     rpc.PacayaClients.ForkHeight,
		StartHeight:          new(big.Int).Sub(proposedIn, common.Big1),
		EndHeight:            proposedIn,
		OnBlockProposedEvent: callback,
	})
	if err != nil {
		log.Error("Failed to start event iterator", "event", "BlockProposed", "error", err)
		return nil, err
	}

	if err := iter.Iter(); err != nil {
		return nil, err
	}

	if m == nil {
		return nil, fmt.Errorf("failed to find BlockProposedV2 event for block %d", id)
	}

	return m, nil
}

// IsProvingWindowExpired returns true as the first return parameter if the assigned prover
// proving window of the given proposed block is expired, and the second return parameter is the time
// remaining til proving window is expired.
func IsProvingWindowExpired(
	rpc *rpc.Client,
	metadata metadata.TaikoProposalMetaData,
	tiers []*rpc.TierProviderTierWithID,
) (bool, time.Time, time.Duration, error) {
	var (
		provingWindow time.Duration
		timestamp     uint64
		err           error
	)
	if metadata.IsPacaya() {
		protocolConfigs, err := rpc.GetProtocolConfigs(nil)
		if err != nil {
			return false, time.Time{}, 0, fmt.Errorf("failed to get Pacaya protocol configs: %w", err)
		}
		if provingWindow, err = protocolConfigs.ProvingWindow(); err != nil {
			return false, time.Time{}, 0, fmt.Errorf("failed to get Pacaya proving window: %w", err)
		}
		timestamp = metadata.Pacaya().GetProposedAt()
	} else {
		if provingWindow, err = getProvingWindowOntake(
			metadata.Ontake().GetMinTier(),
			tiers,
		); err != nil {
			return false, time.Time{}, 0, fmt.Errorf("failed to get Ontake proving window: %w", err)
		}
		timestamp = metadata.Ontake().GetTimestamp()
	}

	var (
		now       = uint64(time.Now().Unix())
		expiredAt = timestamp + uint64(provingWindow.Seconds())
	)
	return now > expiredAt, time.Unix(int64(expiredAt), 0), time.Duration(expiredAt-now) * time.Second, nil
}
