package builder

import (
	"context"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// getParentMetaHash returns the meta hash of the parent block of the latest proposed block in protocol.
func getParentMetaHash(ctx context.Context, rpc *rpc.Client, forkHeight *big.Int) (common.Hash, error) {
	state, err := rpc.TaikoL1.State(&bind.CallOpts{Context: ctx})
	if err != nil {
		return common.Hash{}, err
	}

	blockNum := new(big.Int).SetUint64(state.SlotB.NumBlocks - 1)
	var parent bindings.TaikoDataBlockV2
	if isBlockForked(forkHeight, blockNum) {
		parent, err = rpc.GetL2BlockInfoV2(ctx, blockNum)
	} else {
		parent, err = rpc.GetL2BlockInfo(ctx, blockNum)
	}
	if err != nil {
		return common.Hash{}, err
	}

	return parent.MetaHash, nil
}

// isBlockForked returns whether a fork scheduled at block s is active at the
// given head block.
func isBlockForked(s, head *big.Int) bool {
	if s == nil || head == nil {
		return false
	}
	return s.Cmp(head) <= 0
}
