package repo

import (
	"context"
	"math/big"
	"net/http"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/morkid/paginate"
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

func (r *EventRepository) FindAllByAddressAndChainID(
	ctx context.Context,
	chainID *big.Int,
	address common.Address,
) ([]*relayer.Event, error) {
	e := make([]*relayer.Event, 0)
	// find all message sent events
	if err := r.db.GormDB().Where("chain_id = ?", chainID.Int64()).
		Where("message_owner = ?", strings.ToLower(address.Hex())).
		Find(&e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Find")
	}

	// find all message status changed events

	return e, nil
}

func (r *EventRepository) FindAllByAddress(
	ctx context.Context,
	req *http.Request,
	address common.Address,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().
		Model(&relayer.Event{}).Where("message_owner = ?", strings.ToLower(address.Hex()))

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]relayer.Event{})

	return page, nil
}
