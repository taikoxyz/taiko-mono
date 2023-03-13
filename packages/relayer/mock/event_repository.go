package mock

import (
	"context"
	"encoding/json"
	"math/rand"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"gorm.io/datatypes"
)

type EventRepository struct {
	events []*relayer.Event
}

func NewEventRepository() *EventRepository {
	return &EventRepository{
		events: make([]*relayer.Event, 0),
	}
}
func (r *EventRepository) Save(ctx context.Context, opts relayer.SaveEventOpts) (*relayer.Event, error) {
	r.events = append(r.events, &relayer.Event{
		ID:           rand.Int(), // nolint: gosec
		Data:         datatypes.JSON(opts.Data),
		Status:       opts.Status,
		ChainID:      opts.ChainID.Int64(),
		Name:         opts.Name,
		MessageOwner: opts.MessageOwner,
		MsgHash:      opts.MsgHash,
	})

	return nil, nil
}

func (r *EventRepository) UpdateStatus(ctx context.Context, id int, status relayer.EventStatus) error {
	var event *relayer.Event

	var index int

	for i, e := range r.events {
		if e.ID == id {
			event = e
			index = i

			break
		}
	}

	if event == nil {
		return nil
	}

	event.Status = status

	r.events[index] = event

	return nil
}

func (r *EventRepository) FindAllByAddress(
	ctx context.Context,
	opts relayer.FindAllByAddressOpts,
) ([]*relayer.Event, error) {
	type d struct {
		Owner string `json:"Owner"`
	}

	events := make([]*relayer.Event, 0)

	for _, e := range r.events {
		m, err := e.Data.MarshalJSON()
		if err != nil {
			return nil, err
		}

		data := &d{}
		if err := json.Unmarshal(m, data); err != nil {
			return nil, err
		}

		if data.Owner == opts.Address.Hex() {
			events = append(events, e)
			break
		}
	}

	return events, nil
}

func (r *EventRepository) FindAllByMsgHash(
	ctx context.Context,
	msgHash string,
) ([]*relayer.Event, error) {
	events := make([]*relayer.Event, 0)

	for _, e := range r.events {
		if e.MsgHash == msgHash {
			events = append(events, e)
		}
	}

	return events, nil
}
