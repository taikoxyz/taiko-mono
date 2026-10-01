package rpc

import (
	"context"
	"fmt"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
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
