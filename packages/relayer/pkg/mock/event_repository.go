package mock

import (
	"context"
	"encoding/json"
	"errors"
	"math/rand"
	"net/http"

	"github.com/morkid/paginate"
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
		DestChainID:  opts.DestChainID.Int64(),
		Name:         opts.Name,
		MessageOwner: opts.MessageOwner,
		MsgHash:      opts.MsgHash,
		EventType:    opts.EventType,
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
	req *http.Request,
	opts relayer.FindAllByAddressOpts,
) (paginate.Page, error) {
	type d struct {
		Owner string `json:"Owner"`
	}

	events := make([]*relayer.Event, 0)

	for _, e := range r.events {
		m, err := e.Data.MarshalJSON()
		if err != nil {
			return paginate.Page{}, err
		}

		data := &d{}
		if err := json.Unmarshal(m, data); err != nil {
			return paginate.Page{}, err
		}

		if data.Owner == opts.Address.Hex() {
			events = append(events, e)
			break
		}
	}

	return paginate.Page{
		Items: events,
	}, nil
}

func (r *EventRepository) FirstByMsgHash(
	ctx context.Context,
	msgHash string,
) (*relayer.Event, error) {
	for _, e := range r.events {
		if e.MsgHash == msgHash {
			return e, nil
		}
	}

	return nil, nil
}

func (r *EventRepository) FirstByEventAndMsgHash(
	ctx context.Context,
	event string,
	msgHash string,
) (*relayer.Event, error) {
	for _, e := range r.events {
		if e.MsgHash == msgHash && e.Event == event {
			return e, nil
		}
	}

	return nil, nil
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

func (r *EventRepository) ChainDataSyncedEventByBlockNumberOrGreater(
	ctx context.Context,
	srcChainId uint64,
	syncedChainId uint64,
	blockNumber uint64,
) (*relayer.Event, error) {
	return &relayer.Event{
		ID:      rand.Int(), // nolint: gosec
		ChainID: MockChainID.Int64(),
	}, nil
}

func (r *EventRepository) LatestChainDataSyncedEvent(
	ctx context.Context,
	srcChainId uint64,
	syncedChainId uint64,
) (uint64, error) {
	return 5, nil
}

// DeleteAllAfterBlockID is used when a reorg is detected
func (r *EventRepository) DeleteAllAfterBlockID(blockID uint64, srcChainID uint64, destChainID uint64) error {
	return nil
}

// GetLatestBlockID get latest block id
func (r *EventRepository) FindLatestBlockID(
	event string,
	srcChainID uint64,
	destChainID uint64,
) (uint64, error) {
	if srcChainID == MockChainID.Uint64() {
		return LatestBlockNumber.Uint64(), nil
	}

	return 0, errors.New("invalid")
}
