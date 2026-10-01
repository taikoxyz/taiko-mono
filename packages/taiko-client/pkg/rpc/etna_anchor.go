package rpc

import (
	"context"
	"fmt"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
)

// EtnaAnchorHeader returns the L1 header an Etna L2 block anchors to, whose hash the block commits as
// its parentBeaconBlockRoot. It returns the L1 client's error unchanged, so callers can detect
// ethereum.NotFound.
func (c *Client) EtnaAnchorHeader(ctx context.Context, l2Header *types.Header) (*types.Header, error) {
	if l2Header.ParentBeaconRoot == nil || *l2Header.ParentBeaconRoot == (common.Hash{}) {
		return nil, fmt.Errorf("missing L1 anchor block hash in Etna block %d", l2Header.Number)
	}

	return c.L1.HeaderByHash(ctx, *l2Header.ParentBeaconRoot)
}

// EtnaAnchorBlockNumber returns the anchor block number of a built Etna L2 block, the protocol's
// `parent.metadata.anchorBlockNumber`: zero for the genesis block, otherwise the number of the L1
// block whose hash the block commits as its parentBeaconBlockRoot.
func (c *Client) EtnaAnchorBlockNumber(ctx context.Context, l2Header *types.Header) (uint64, error) {
	if l2Header.Number.Sign() == 0 {
		return 0, nil
	}

	anchorHeader, err := c.EtnaAnchorHeader(ctx, l2Header)
	if err != nil {
		return 0, err
	}

	return anchorHeader.Number.Uint64(), nil
}

// isEtnaAnchorReorged reports whether the L1 block an Etna L2 block anchors to is no longer canonical:
// the L1 node no longer knows it, or another block replaced it at its height.
func (c *Client) isEtnaAnchorReorged(ctx context.Context, l2Header *types.Header) (bool, error) {
	anchorHeader, err := c.EtnaAnchorHeader(ctx, l2Header)
	if err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			log.Info(
				"Reorg detected due to missing Etna anchor block",
				"blockID", l2Header.Number,
				"anchorBlockHash", l2Header.ParentBeaconRoot,
			)
			return true, nil
		}
		return false, err
	}

	canonical, err := c.L1.HeaderByNumber(ctx, anchorHeader.Number)
	if err != nil {
		if err.Error() == ethereum.NotFound.Error() {
			log.Info("Reorg detected due to missing canonical L1 block", "anchorBlockNumber", anchorHeader.Number)
			return true, nil
		}
		return false, err
	}
	if canonical.Hash() != *l2Header.ParentBeaconRoot {
		log.Info(
			"Reorg detected due to Etna anchor block hash mismatch",
			"blockID", l2Header.Number,
			"anchorBlockNumber", anchorHeader.Number,
			"anchorBlockHash", l2Header.ParentBeaconRoot,
			"canonicalHash", canonical.Hash(),
		)
		return true, nil
	}

	return false, nil
}
