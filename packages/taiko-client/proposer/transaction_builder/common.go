package builder

import (
	"context"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// getParent returns the parent block of the latest proposed block in protocol.
func getParent(ctx context.Context, rpc *rpc.Client) (*bindings.TaikoDataBlock, error) {
	state, err := rpc.TaikoL1.State(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, err
	}

	parent, err := rpc.GetL2BlockInfo(ctx, new(big.Int).SetUint64(state.SlotB.NumBlocks-1))
	if err != nil {
		return nil, err
	}

	return &parent, nil
}
