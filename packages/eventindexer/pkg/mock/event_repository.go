package mock

import (
	"context"
	"errors"
	"math/big"
	"math/rand"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/datatypes"
	"gorm.io/gorm"
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

func (r *EventRepository) GetByAddressAndEventName(
	ctx context.Context,
	req *http.Request,
	address string,
	event string,
) (paginate.Page, error) {
	var events []*eventindexer.Event

	for _, e := range r.events {
		if e.Address == address && e.Event == event {
			events = append(events, e)
		}
	}

	return paginate.Page{
		Items: events,
	}, nil
}

func (r *EventRepository) FindByEventTypeAndBlockID(
	ctx context.Context,
	eventType string,
	blockID int64) (*eventindexer.Event, error) {
	for _, e := range r.events {
		if e.Event == eventType && e.BlockID.Int64 == blockID {
			return e, nil
		}
	}

	return nil, gorm.ErrRecordNotFound
}

func (r *EventRepository) Delete(
	ctx context.Context,
	id int,
) error {
	for i, e := range r.events {
		if e.ID == id {
			r.events = append(r.events[:i], r.events[i+1:]...)
		}
	}

	return nil
}

func (r *EventRepository) GetTotalSlashedTokens(
	ctx context.Context,
) (*big.Int, error) {
	return big.NewInt(1), nil
}

func (r *EventRepository) FirstByAddressAndEventName(
	ctx context.Context,
	address string,
	event string,
) (*eventindexer.Event, error) {
	for _, e := range r.events {
		if e.Address == address && e.Event == event {
			return e, nil
		}
	}

	return nil, nil
}

func (r *EventRepository) GetAssignedBlocksByProverAddress(
	ctx context.Context,
	req *http.Request,
	address string,
) (paginate.Page, error) {
	var events []*eventindexer.Event

	for _, e := range r.events {
		if e.AssignedProver == address && e.Event == eventindexer.EventNameBlockProposed {
			events = append(events, e)
		}
	}

	return paginate.Page{
		Items: events,
	}, nil
}

// DeleteAllAfterBlockID is used when a reorg is detected
func (r *EventRepository) DeleteAllAfterBlockID(blockID uint64, srcChainID uint64) error {
	return nil
}

// GetLatestBlockID get latest block id
func (r *EventRepository) FindLatestBlockID(
	srcChainID uint64,
) (uint64, error) {
	if srcChainID == MockChainID.Uint64() {
		return LatestBlockNumber.Uint64(), nil
	}

	return 0, errors.New("invalid")
}
