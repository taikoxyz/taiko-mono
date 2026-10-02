package rpc

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// CheckEtnaSchedule checks that the given L2 head agrees with the client's Etna schedule. The head's
// parentBeaconBlockRoot tells the forks apart: nil before Unzen, zero during Unzen, and from Etna on the
// non-zero hash of the block's L1 anchor block. The genesis block always passes. A mismatch means the
// client's Etna activation time differs from the execution engine's, so the client would derive, propose
// and prove blocks under the wrong fork rules.
func CheckEtnaSchedule(chainID *big.Int, head *types.Header) error {
	if head == nil {
		return errors.New("missing L2 head header")
	}
	if head.Number.Sign() == 0 {
		return nil
	}

	committedAnchor := head.ParentBeaconRoot != nil && *head.ParentBeaconRoot != (common.Hash{})
	if IsEtna(chainID, head.Time) == committedAnchor {
		return nil
	}

	root, fork := "none", "a pre-Etna block"
	if head.ParentBeaconRoot != nil {
		root = head.ParentBeaconRoot.Hex()
	}
	if committedAnchor {
		fork = "an Etna block"
	}
	return fmt.Errorf(
		"L2 head block %d (timestamp %d, parentBeaconBlockRoot %s) is %s, but the client's fork schedule "+
			"expects %s at that timestamp: the client's Etna activation time must match the execution engine's "+
			"(on a devnet, set --taiko.devnet-etna-time to the execution engine's Etna time)",
		head.Number, head.Time, root, fork, ForkLabel(chainID, head.Time),
	)
}

// CheckEtnaSchedule fetches the latest L2 head and checks it against the client's Etna schedule, see the
// CheckEtnaSchedule function.
func (c *Client) CheckEtnaSchedule(ctx context.Context) error {
	head, err := c.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to fetch the L2 head: %w", err)
	}

	return CheckEtnaSchedule(c.L2.ChainID, head)
}
