package testutils

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/utils"
)

type BlobSyncer interface {
	ProcessL1Blocks(ctx context.Context) error
}

type Proposer interface {
	utils.SubcommandApplication
	ProposeOp(ctx context.Context) error
	ProposeTxList(
		ctx context.Context,
		txListBytes []byte,
		txNum uint,
	) error
}
