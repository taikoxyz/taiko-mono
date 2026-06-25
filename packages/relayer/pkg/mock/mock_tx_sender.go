package mock

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rpc"
)

type TxManager struct {
	FromAddress common.Address
	Candidate   txmgr.TxCandidate
	Receipt     *types.Receipt
	Sent        bool
}

func (t *TxManager) Send(ctx context.Context, candidate txmgr.TxCandidate) (*types.Receipt, error) {
	t.Candidate = candidate
	t.Sent = true

	if t.Receipt != nil {
		return t.Receipt, nil
	}

	return &types.Receipt{}, nil
}

// From returns the sending address associated with the instance of the transaction manager.
// It is static for a single instance of a TxManager.
func (t *TxManager) From() common.Address {
	if t.FromAddress != (common.Address{}) {
		return t.FromAddress
	}

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

func (t *TxManager) SendAsync(ctx context.Context, candidate txmgr.TxCandidate, ch chan txmgr.SendResponse) {
	panic("unimplemented")
}

func (t *TxManager) SuggestGasPriceCaps(ctx context.Context) (
	tipCap *big.Int,
	baseFee *big.Int,
	blobBaseFee *big.Int,
	err error,
) {
	panic("unimplemented")
}

func (t *TxManager) API() rpc.API {
	panic("unimplemented")
}
