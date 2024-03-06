package mock

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type SuspendedTransactionRepository struct {
	latestId int
	txs      []*relayer.SuspendedTransaction
}

func NewSuspendedTransactionRepository() *SuspendedTransactionRepository {
	return &SuspendedTransactionRepository{
		latestId: 0,
		txs:      make([]*relayer.SuspendedTransaction, 0),
	}
}
func (r *SuspendedTransactionRepository) Save(
	ctx context.Context,
	opts relayer.SuspendTransactionOpts,
) (*relayer.SuspendedTransaction, error) {
	r.latestId++

	tx := &relayer.SuspendedTransaction{
		ID:           r.latestId, // nolint: gosec
		MessageOwner: opts.MessageOwner,
		MsgHash:      opts.MsgHash,
		MessageID:    opts.MessageID,
		SrcChainID:   opts.SrcChainID,
		DestChainID:  opts.DestChainID,
		Suspended:    opts.Suspended,
	}
	r.txs = append(r.txs, tx)

	return tx, nil
}

func (r *SuspendedTransactionRepository) Find(
	ctx context.Context,
	req *http.Request,
) (paginate.Page, error) {
	return paginate.Page{
		Items: r.txs,
	}, nil
}
