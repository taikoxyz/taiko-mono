package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type SuspendedTransactionRepository struct {
	db DB
}

func NewSuspendedTransactionRepository(db DB) (*SuspendedTransactionRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &SuspendedTransactionRepository{
		db: db,
	}, nil
}

func (r *SuspendedTransactionRepository) Save(
	ctx context.Context,
	opts relayer.SuspendTransactionOpts,
) (*relayer.SuspendedTransaction, error) {
	e := &relayer.SuspendedTransaction{
		MsgHash:      opts.MsgHash,
		MessageOwner: opts.MessageOwner,
		MessageID:    opts.MessageID,
		SrcChainID:   opts.SrcChainID,
		DestChainID:  opts.DestChainID,
		Suspended:    opts.Suspended,
	}

	if err := r.db.GormDB().Create(e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Create")
	}

	return e, nil
}

func (r *SuspendedTransactionRepository) Find(
	ctx context.Context,
	req *http.Request,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().
		Model(&relayer.SuspendedTransaction{})

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]relayer.SuspendedTransaction{})

	return page, nil
}
