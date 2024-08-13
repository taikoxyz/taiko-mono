package builder

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// getParentMetaHash returns the meta hash of the parent block of the latest proposed block in protocol.
func getParentMetaHash(ctx context.Context, rpc *rpc.Client) (common.Hash, error) {
	state, err := rpc.V2.TaikoL1.State(&bind.CallOpts{Context: ctx})
	if err != nil {
		return common.Hash{}, err
	}

	parent, err := rpc.GetL2BlockInfo(ctx, new(big.Int).SetUint64(state.SlotB.NumBlocks-1))
	if err != nil {
		return common.Hash{}, err
	}

	return parent.MetaHash, nil
}
