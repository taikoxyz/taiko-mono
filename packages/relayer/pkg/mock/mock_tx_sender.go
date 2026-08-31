package mock

import (
	"context"
	"math/big"
	"sync"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rpc"
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

// TxSender is a private endpoint that accepts everything it is offered, recording what it took.
// It satisfies utils.TxSender.
type TxSender struct {
	mu   sync.Mutex
	err  error
	sent []*types.Transaction
}

// NewFailingTxSender returns a sender that refuses every transaction with err.
func NewFailingTxSender(err error) *TxSender {
	return &TxSender{err: err}
}

func (s *TxSender) SendTransaction(_ context.Context, tx *types.Transaction) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.err != nil {
		return s.err
	}

	s.sent = append(s.sent, tx)

	return nil
}

// SentCount returns how many transactions this endpoint accepted. For tests.
func (s *TxSender) SentCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()

	return len(s.sent)
}
