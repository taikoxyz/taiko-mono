package repo

import (
	"context"
	"strings"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"gorm.io/datatypes"
)

type EventRepository struct {
	db relayer.DB
}

func NewEventRepository(db relayer.DB) (*EventRepository, error) {
	if db == nil {
		return nil, relayer.ErrNoDB
	}

	return &EventRepository{
		db: db,
	}, nil
}

func (r *EventRepository) Save(ctx context.Context, opts relayer.SaveEventOpts) (*relayer.Event, error) {
	e := &relayer.Event{
		Data:                   datatypes.JSON(opts.Data),
		Status:                 opts.Status,
		ChainID:                opts.ChainID.Int64(),
		Name:                   opts.Name,
		EventType:              opts.EventType,
		CanonicalTokenAddress:  opts.CanonicalTokenAddress,
		CanonicalTokenSymbol:   opts.CanonicalTokenSymbol,
		CanonicalTokenName:     opts.CanonicalTokenName,
		CanonicalTokenDecimals: opts.CanonicalTokenDecimals,
		Amount:                 opts.Amount,
		MsgHash:                opts.MsgHash,
		MessageOwner:           opts.MessageOwner,
	}
	if err := r.db.GormDB().Create(e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Create")
	}

	return e, nil
}

func (r *EventRepository) UpdateStatus(ctx context.Context, id int, status relayer.EventStatus) error {
	e := &relayer.Event{}
	if err := r.db.GormDB().Where("id = ?", id).First(e).Error; err != nil {
		return errors.Wrap(err, "r.db.First")
	}

	e.Status = status
	if err := r.db.GormDB().Save(e).Error; err != nil {
		return errors.Wrap(err, "r.db.Save")
	}

	return nil
}

func (r *EventRepository) FindAllByMsgHash(
	ctx context.Context,
	msgHash string,
) ([]*relayer.Event, error) {
	e := make([]*relayer.Event, 0)
	// find all message sent events
	if err := r.db.GormDB().Where("msg_hash = ?", msgHash).
		Find(&e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Find")
	}

	// find all message status changed events

	return e, nil
}

func (r *EventRepository) FindAllByAddress(
	ctx context.Context,
	opts relayer.FindAllByAddressOpts,
) ([]*relayer.Event, error) {
	e := make([]*relayer.Event, 0)
	q := r.db.GormDB()

	if opts.EventType != nil {
		q = q.Where("event_type = ?", *opts.EventType)
	}

	if opts.MsgHash != nil && *opts.MsgHash != "" {
		q = q.Where("msg_hash = ?", *opts.MsgHash)
	}

	if opts.ChainID != nil {
		q = q.Where("chain_id = ?", *opts.ChainID)
	}

	if err := q.
		Find(&e, datatypes.JSONQuery("data").
			Equals(strings.ToLower(opts.Address.Hex()), "Message", "Owner")).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Find")
	}

	return e, nil
}
