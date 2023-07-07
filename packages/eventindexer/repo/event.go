package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type EventRepository struct {
	db eventindexer.DB
}

func NewEventRepository(db eventindexer.DB) (*EventRepository, error) {
	if db == nil {
		return nil, eventindexer.ErrNoDB
	}

	return &EventRepository{
		db: db,
	}, nil
}

func (r *EventRepository) Save(ctx context.Context, opts eventindexer.SaveEventOpts) (*eventindexer.Event, error) {
	e := &eventindexer.Event{
		Data:    datatypes.JSON(opts.Data),
		ChainID: opts.ChainID.Int64(),
		Name:    opts.Name,
		Event:   opts.Event,
		Address: opts.Address,
	}

	if err := r.db.GormDB().Create(e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Create")
	}

	return e, nil
}

func (r *EventRepository) FindByEventTypeAndBlockID(
	ctx context.Context,
	eventType string,
	blockID int64) (*eventindexer.Event, error) {
	e := &eventindexer.Event{}

	if err := r.db.GormDB().
		Where("event = ?", eventType).
		Where("block_id = ?", blockID).First(e).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}

		return nil, err
	}

	return e, nil
}

func (r *EventRepository) Delete(
	ctx context.Context,
	id int,
) error {
	e := &eventindexer.Event{}

	return r.db.GormDB().Delete(e, id).Error
}

func (r *EventRepository) FindUniqueProvers(
	ctx context.Context,
) ([]eventindexer.UniqueProversResponse, error) {
	addrs := make([]eventindexer.UniqueProversResponse, 0)

	if err := r.db.GormDB().
		Raw("SELECT address, count(*) AS count FROM events WHERE event = ? GROUP BY address",
			eventindexer.EventNameBlockProven).
		FirstOrInit(&addrs).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.FirstOrInit")
	}

	return addrs, nil
}

func (r *EventRepository) FindUniqueProposers(
	ctx context.Context,
) ([]eventindexer.UniqueProposersResponse, error) {
	addrs := make([]eventindexer.UniqueProposersResponse, 0)

	if err := r.db.GormDB().
		Raw("SELECT address, count(*) AS count FROM events WHERE event = ? GROUP BY address",
			eventindexer.EventNameBlockProposed).
		FirstOrInit(&addrs).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.FirstOrInit")
	}

	return addrs, nil
}

func (r *EventRepository) GetCountByAddressAndEventName(
	ctx context.Context,
	address string,
	event string,
) (int, error) {
	var count int

	if err := r.db.GormDB().
		Raw("SELECT count(*) AS count FROM events WHERE event = ? AND address = ?", event, address).
		FirstOrInit(&count).Error; err != nil {
		return 0, errors.Wrap(err, "r.db.FirstOrInit")
	}

	return count, nil
}

func (r *EventRepository) GetByAddressAndEventName(
	ctx context.Context,
	req *http.Request,
	address string,
	event string,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().
		Raw("SELECT * FROM events WHERE event = ? AND address = ?", event, address)

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]eventindexer.Event{})

	return page, nil
}

func (r *EventRepository) FirstByAddressAndEventName(
	ctx context.Context,
	address string,
	event string,
) (*eventindexer.Event, error) {
	e := &eventindexer.Event{}

	if err := r.db.GormDB().
		Where("address = ?", address).
		Where("event = ?", event).
		First(e).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}

		return nil, err
	}

	return e, nil
}
