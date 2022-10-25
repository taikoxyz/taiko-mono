package repo

import (
	"github.com/taikochain/taiko-mono/packages/relayer"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type EventRepository struct {
	db *gorm.DB
}

func NewEventRepository(db *gorm.DB) (*EventRepository, error) {
	if db == nil {
		return nil, relayer.ErrNoDB
	}

	return &EventRepository{
		db: db,
	}, nil
}

func (r *EventRepository) Save(opts relayer.SaveEventOpts) error {
	e := &relayer.Event{
		Data:    datatypes.JSON(opts.Data),
		Status:  relayer.EventStatusNew,
		ChainID: opts.ChainID.Int64(),
		Name:    opts.Name,
	}
	if err := r.db.Create(e).Error; err != nil {
		return err
	}
	return nil
}
