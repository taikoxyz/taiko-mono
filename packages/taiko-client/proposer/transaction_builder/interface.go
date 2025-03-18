package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
)

// ProposeBlockTransactionBuilder is an interface for building a TaikoL1.proposeBlock transaction.
type ProposeBlockTransactionBuilder interface {
	BuildOntake(ctx context.Context, txListBytesArray [][]byte, parentMetahash common.Hash) (*txmgr.TxCandidate, error)
}
