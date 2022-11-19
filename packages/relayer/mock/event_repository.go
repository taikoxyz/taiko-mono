package mock

import (
	"github.com/taikochain/taiko-mono/packages/relayer"
)

type EventRepository struct {
}

func (r *EventRepository) Save(opts relayer.SaveEventOpts) (*relayer.Event, error) {
	return nil, nil
}

func (r *EventRepository) UpdateStatus(id int, status relayer.EventStatus) error {
	return nil
}
