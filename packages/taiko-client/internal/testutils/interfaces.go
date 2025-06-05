package testutils

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/utils"
)

type ChainSyncer interface {
	ProcessL1Blocks(ctx context.Context) error
}

type Proposer interface {
	utils.SubcommandApplication
	ProposeOp(ctx context.Context) error
	ProposeTxLists(ctx context.Context, txLists []types.Transactions, parentMetaHash common.Hash) error
	RegisterTxMgrSelectorToBlobServer(blobServer *MemoryBlobServer)
}
