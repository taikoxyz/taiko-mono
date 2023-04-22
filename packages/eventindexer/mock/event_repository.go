package mock

import (
	"context"
	"math/rand"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/datatypes"
)

type EventRepository struct {
	events []*eventindexer.Event
}

func NewEventRepository() *EventRepository {
	return &EventRepository{
		events: make([]*eventindexer.Event, 0),
	}
}
func (r *EventRepository) Save(ctx context.Context, opts eventindexer.SaveEventOpts) (*eventindexer.Event, error) {
	r.events = append(r.events, &eventindexer.Event{
		ID:      rand.Int(), // nolint: gosec
		Data:    datatypes.JSON(opts.Data),
		ChainID: opts.ChainID.Int64(),
		Name:    opts.Name,
		Event:   opts.Event,
		Address: opts.Address,
	})

	return nil, nil
}

func (r *EventRepository) FindUniqueProposers(
	ctx context.Context,
) ([]eventindexer.UniqueProposersResponse, error) {
	return make([]eventindexer.UniqueProposersResponse, 0), nil
}

func (r *EventRepository) FindUniqueProvers(
	ctx context.Context,
) ([]eventindexer.UniqueProversResponse, error) {
	return make([]eventindexer.UniqueProversResponse, 0), nil
}

func (r *EventRepository) GetCountByAddressAndEventName(
	ctx context.Context,
	address string,
	event string,
) (int, error) {
	var count int = 0

	for _, e := range r.events {
		if e.Address == address && e.Event == event {
			count++
		}
	}

	return count, nil
}
