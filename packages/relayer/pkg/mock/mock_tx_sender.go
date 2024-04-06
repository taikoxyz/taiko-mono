package mock

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

type TxManager struct {
}

func (t *TxManager) Send(ctx context.Context, candidate txmgr.TxCandidate) (*types.Receipt, error) {
	return &types.Receipt{}, nil
}

// From returns the sending address associated with the instance of the transaction manager.
// It is static for a single instance of a TxManager.
func (t *TxManager) From() common.Address {
	return common.HexToAddress("0x123")
}

// BlockNumber returns the most recent block number from the underlying network.
func (t *TxManager) BlockNumber(ctx context.Context) (uint64, error) {
	return 0, nil
}

// Close the underlying connection
func (t *TxManager) Close() {

}

func (t *TxManager) IsClosed() bool {
	return false
}
