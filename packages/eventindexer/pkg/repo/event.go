package repo

import (
	"context"
	"database/sql"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"github.com/shopspring/decimal"
	"gorm.io/datatypes"
	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

type EventRepository struct {
	db db.DB
}

func NewEventRepository(dbHandler db.DB) (*EventRepository, error) {
	if dbHandler == nil {
		return nil, db.ErrNoDB
	}

	return &EventRepository{
		db: dbHandler,
	}, nil
}

func (r *EventRepository) Save(ctx context.Context, opts eventindexer.SaveEventOpts) (*eventindexer.Event, error) {
	e := &eventindexer.Event{
		Data:           datatypes.JSON(opts.Data),
		ChainID:        opts.ChainID.Int64(),
		Name:           opts.Name,
		Event:          opts.Event,
		Address:        opts.Address,
		TransactedAt:   opts.TransactedAt,
		EmittedBlockID: opts.EmittedBlockID,
	}

	if opts.Tier != nil {
		e.Tier = sql.NullInt16{
			Valid: true,
			Int16: int16(*opts.Tier),
		}
	}

	if opts.BlockID != nil {
		e.BlockID = sql.NullInt64{
			Valid: true,
			Int64: *opts.BlockID,
		}
	}

	if opts.NumBlocks != nil {
		e.NumBlocks = sql.NullInt64{
			Valid: true,
			Int64: *opts.NumBlocks,
		}
	}

	if opts.Amount != nil {
		amt, err := decimal.NewFromString(opts.Amount.String())
		if err != nil {
			return nil, errors.Wrap(err, "decimal.NewFromString")
		}

		e.Amount = decimal.NullDecimal{
			Valid:   true,
			Decimal: amt,
		}
	}

	if opts.ProposerReward != nil {
		amt, err := decimal.NewFromString(opts.ProposerReward.String())
		if err != nil {
			return nil, errors.Wrap(err, "decimal.NewFromString")
		}

		e.ProposerReward = decimal.NullDecimal{
			Valid:   true,
			Decimal: amt,
		}
	}

	if opts.ProofReward != nil {
		amt, err := decimal.NewFromString(opts.ProofReward.String())
		if err != nil {
			return nil, errors.Wrap(err, "decimal.NewFromString")
		}

		e.ProofReward = decimal.NullDecimal{
			Valid:   true,
			Decimal: amt,
		}
	}

	if opts.AssignedProver != nil {
		e.AssignedProver = *opts.AssignedProver
	}

	if opts.TokenID != nil {
		e.TokenID = sql.NullInt64{
			Valid: true,
			Int64: *opts.TokenID,
		}
	}

	if opts.BatchID != nil {
		e.BatchID = sql.NullInt64{
			Valid: true,
			Int64: *opts.BatchID,
		}
	}

	if opts.To != nil {
		e.To = *opts.To
	}

	if opts.ContractAddress != nil {
		e.ContractAddress = *opts.ContractAddress
	}

	if opts.FeeTokenAddress != nil {
		e.FeeTokenAddress = *opts.FeeTokenAddress
	}

	if err := r.db.GormDB().WithContext(ctx).Create(e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Create")
	}

	return e, nil
}

func (r *EventRepository) FindByEventTypeAndBlockID(
	ctx context.Context,
	eventType string,
	blockID int64) (*eventindexer.Event, error) {
	e := &eventindexer.Event{}

	if err := r.db.GormDB().WithContext(ctx).
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

	return r.db.GormDB().WithContext(ctx).Delete(e, id).Error
}

func (r *EventRepository) FindUniqueProvers(
	ctx context.Context,
) ([]eventindexer.UniqueProversResponse, error) {
	addrs := make([]eventindexer.UniqueProversResponse, 0)

	events := []string{
		eventindexer.EventNameTransitionProved,
		eventindexer.EventNameBatchesProven,
		eventindexer.EventNameProved,
	}

	if err := r.db.GormDB().WithContext(ctx).
		Raw("SELECT address, count(*) AS count FROM events WHERE event IN (?) GROUP BY address", events).
		Scan(&addrs).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Scan")
	}

	return addrs, nil
}

func (r *EventRepository) FindUniqueProposers(
	ctx context.Context,
) ([]eventindexer.UniqueProposersResponse, error) {
	addrs := make([]eventindexer.UniqueProposersResponse, 0)

	events := []string{
		eventindexer.EventNameBlockProposed,
		eventindexer.EventNameBatchProposed,
		eventindexer.EventNameProposed,
	}

	if err := r.db.GormDB().WithContext(ctx).
		Raw("SELECT address, count(*) AS count FROM events WHERE event IN (?) GROUP BY address", events).
		Scan(&addrs).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Scan")
	}

	return addrs, nil
}

func (r *EventRepository) GetCountByAddressAndEventName(
	ctx context.Context,
	address string,
	event string,
) (int, error) {
	var count int

	if err := r.db.GormDB().WithContext(ctx).
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

	q := r.db.GormDB().WithContext(ctx).
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

	if err := r.db.GormDB().WithContext(ctx).
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

func (r *EventRepository) GetAssignedBlocksByProverAddress(
	ctx context.Context,
	req *http.Request,
	address string,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().WithContext(ctx).
		Raw("SELECT * FROM events WHERE event = ? AND assigned_prover = ?", eventindexer.EventNameBlockProposed, address)

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]eventindexer.Event{})

	return page, nil
}

// DeleteAllAfterBlockID is used when a reorg is detected
func (r *EventRepository) DeleteAllAfterBlockID(ctx context.Context, blockID uint64, srcChainID uint64) error {
	query := `
DELETE FROM events
WHERE block_id >= ? AND chain_id = ?`

	return r.db.GormDB().WithContext(ctx).Table("events").Exec(query, blockID, srcChainID).Error
}

// FindLatestBlockID gets the latest block id
func (r *EventRepository) FindLatestBlockID(
	ctx context.Context,
	srcChainID uint64,
) (uint64, error) {
	q := `SELECT COALESCE(MAX(emitted_block_id), 0)
	FROM events WHERE chain_id = ?`

	var b uint64

	if err := r.db.GormDB().WithContext(ctx).Table("events").Raw(q, srcChainID).Scan(&b).Error; err != nil {
		return 0, err
	}

	return b, nil
}

func (r *EventRepository) GetBlockProvenBy(ctx context.Context, blockID int) ([]*eventindexer.Event, error) {
	e := []*eventindexer.Event{}
	// First, try to find a direct TransitionProved event
	err := r.db.GormDB().WithContext(ctx).
		Where("block_id = ?", blockID).
		Where("event = ?", eventindexer.EventNameTransitionProved).
		Find(&e).Error

	if err != nil {
		return nil, err
	}

	if len(e) > 0 {
		return e, nil
	}
	// Try to find the batch this block belongs to
	batchEvent := &eventindexer.Event{}
	err = r.db.GormDB().WithContext(ctx).
		Where("event = ?", eventindexer.EventNameBatchProposed).
		Where("? BETWEEN (block_id - num_blocks + 1) AND block_id", blockID).
		First(batchEvent).Error

	if err != nil {
		return nil, err
	}

	err = r.db.GormDB().WithContext(ctx).
		Where("event = ?", eventindexer.EventNameBatchesProven).
		Where("batch_id = ?", batchEvent.BatchID.Int64).
		Find(&e).Error

	if err != nil {
		return nil, err
	}

	return e, nil
}

func (r *EventRepository) GetBlockProposedBy(ctx context.Context, blockID int) (*eventindexer.Event, error) {
	e := &eventindexer.Event{}

	// First, try to find a direct BlockProposed event
	err := r.db.GormDB().WithContext(ctx).
		Where("block_id = ?", blockID).
		Where("event = ?", eventindexer.EventNameBlockProposed).
		First(&e).Error

	if err == nil {
		return e, nil
	}

	if err != gorm.ErrRecordNotFound {
		return nil, err
	}
	// Then, try to find a Batch that the block belongs to
	if err := r.db.GormDB().WithContext(ctx).
		Where("event = ?", eventindexer.EventNameBatchProposed).
		Where("? BETWEEN (block_id - num_blocks + 1) AND block_id", blockID).
		First(&e).Error; err != nil {
		return nil, err
	}

	return e, nil
}

// shasta exclusive api, since proposals reset to id = 1 after genesis in Shasta and reusing GetBlockProposedBy will overlap
func (r *EventRepository) GetProposalProposedBy(ctx context.Context, proposalID int) (*eventindexer.Event, error) {
	e := &eventindexer.Event{}
	// try to find direct Proposed event
	err := r.db.GormDB().WithContext(ctx).
		Where("event = ?", eventindexer.EventNameProposed).
		Where("batch_id = ?", proposalID).
		First(&e).Error

	if err == nil {
		return e, nil
	}

	if err != gorm.ErrRecordNotFound {
		return nil, err
	}

	return nil, nil
}

func (r *EventRepository) GetProposalProvedBy(ctx context.Context, proposalID int) (*eventindexer.Event, error) {
	e := &eventindexer.Event{}
	// try to find direct Proposed event
	err := r.db.GormDB().WithContext(ctx).
		Where("event = ?", eventindexer.EventNameProved).
		Where("batch_id = ?", proposalID).
		First(&e).Error

	if err == nil {
		return e, nil
	}

	if err != gorm.ErrRecordNotFound {
		return nil, err
	}

	return nil, nil
}
