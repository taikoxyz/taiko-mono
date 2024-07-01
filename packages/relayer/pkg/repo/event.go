package repo

import (
	"strings"
	"time"

	"net/http"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"gorm.io/datatypes"
	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type EventRepository struct {
}

func (r *EventRepository) Save(db *gorm.DB, opts *relayer.SaveEventOpts) (*relayer.Event, error) {
	e := &relayer.Event{
		Data:                   datatypes.JSON(opts.Data),
		Status:                 opts.Status,
		ChainID:                opts.ChainID.Int64(),
		DestChainID:            opts.DestChainID.Int64(),
		Name:                   opts.Name,
		EventType:              opts.EventType,
		CanonicalTokenAddress:  opts.CanonicalTokenAddress,
		CanonicalTokenSymbol:   opts.CanonicalTokenSymbol,
		CanonicalTokenName:     opts.CanonicalTokenName,
		CanonicalTokenDecimals: opts.CanonicalTokenDecimals,
		Amount:                 opts.Amount,
		MsgHash:                opts.MsgHash,
		MessageOwner:           opts.MessageOwner,
		Event:                  opts.Event,
		SyncedChainID:          opts.SyncedChainID,
		SyncData:               opts.SyncData,
		Kind:                   opts.Kind,
		SyncedInBlockID:        opts.SyncedInBlockID,
		BlockID:                opts.BlockID,
		EmittedBlockID:         opts.EmittedBlockID,
	}

	if err := db.Create(e).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Create")
	}

	return e, nil
}

func (r *EventRepository) UpdateFeesAndProfitability(
	db *gorm.DB,
	id int,
	opts *relayer.UpdateFeesAndProfitabilityOpts,
) error {
	e := &relayer.Event{}
	if err := db.Where("id = ?", id).First(e).Error; err != nil {
		return errors.Wrap(err, "r.db.First")
	}

	e.Fee = &opts.Fee
	e.DestChainBaseFee = &opts.DestChainBaseFee
	e.GasTipCap = &opts.GasTipCap
	e.GasLimit = &opts.GasLimit
	e.IsProfitable = &opts.IsProfitable
	e.EstimatedOnchainFee = &opts.EstimatedOnchainFee
	currentTime := time.Now().UTC()
	e.IsProfitableEvaluatedAt = &currentTime

	if err := db.Save(e).Error; err != nil {
		return errors.Wrap(err, "r.db.Save")
	}

	return nil
}

func (r *EventRepository) UpdateStatus(db *gorm.DB, id int, status relayer.EventStatus) error {
	e := &relayer.Event{}
	if err := db.Where("id = ?", id).First(e).Error; err != nil {
		return errors.Wrap(err, "r.db.First")
	}

	e.Status = status
	if err := db.Save(e).Error; err != nil {
		return errors.Wrap(err, "r.db.Save")
	}

	return nil
}

func (r *EventRepository) FirstByMsgHash(
	db *gorm.DB,
	msgHash string,
) (*relayer.Event, error) {
	e := &relayer.Event{}
	// find all message sent events
	if err := db.Where("msg_hash = ?", msgHash).
		First(&e).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}

		return nil, errors.Wrap(err, "r.db.First")
	}

	return e, nil
}

func (r *EventRepository) FirstByEventAndMsgHash(
	db *gorm.DB,
	event string,
	msgHash string,
) (*relayer.Event, error) {
	e := &relayer.Event{}
	// find all message sent events
	if err := db.Where("msg_hash = ?", msgHash).
		Where("event = ?", event).
		First(&e).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}

		return nil, errors.Wrap(err, "r.db.First")
	}

	return e, nil
}

func (r *EventRepository) FindAllByAddress(
	db *gorm.DB,
	req *http.Request,
	opts relayer.FindAllByAddressOpts,
) (*paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := db.
		Model(&relayer.Event{}).
		Where(
			"dest_owner_json = ? OR message_owner = ?",
			strings.ToLower(opts.Address.Hex()),
			strings.ToLower(opts.Address.Hex()),
		)

	if opts.EventType != nil {
		q = q.Where("event_type = ?", *opts.EventType)
	}

	if opts.MsgHash != nil && *opts.MsgHash != "" {
		q = q.Where("msg_hash = ?", *opts.MsgHash)
	}

	if opts.ChainID != nil {
		q = q.Where("chain_id = ?", opts.ChainID.Int64())
	}

	if opts.Event != nil && *opts.Event != "" {
		q = q.Where("event = ?", *opts.Event)
	}

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]relayer.Event{})
	if page.Error {
		return nil, page.RawError
	}

	return &page, nil
}

func (r *EventRepository) Delete(
	db *gorm.DB,
	id int,
) error {
	return db.Delete(relayer.Event{}, id).Error
}

func (r *EventRepository) ChainDataSyncedEventByBlockNumberOrGreater(
	db *gorm.DB,
	srcChainId uint64,
	syncedChainId uint64,
	blockNumber uint64,
) (*relayer.Event, error) {
	e := &relayer.Event{}
	// find all message sent events
	if err := db.Where("name = ?", relayer.EventNameChainDataSynced).
		Where("chain_id = ?", srcChainId).
		Where("synced_chain_id = ?", syncedChainId).
		Where("block_id >= ?", blockNumber).
		Order("block_id DESC").
		Limit(1).
		First(&e).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}

		return nil, errors.Wrap(err, "r.db.First")
	}

	return e, nil
}

func (r *EventRepository) LatestChainDataSyncedEvent(
	db *gorm.DB,
	srcChainId uint64,
	syncedChainId uint64,
) (uint64, error) {
	blockID := 0
	// find all message sent events
	if err := db.Table("events").
		Where("chain_id = ?", srcChainId).
		Where("synced_chain_id = ?", syncedChainId).
		Select("COALESCE(MAX(block_id), 0)").
		Scan(&blockID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return 0, nil
		}

		return 0, errors.Wrap(err, "r.db.First")
	}

	return uint64(blockID), nil
}

// DeleteAllAfterBlockID is used when a reorg is detected
func (r *EventRepository) DeleteAllAfterBlockID(db *gorm.DB, blockID uint64, srcChainID uint64, destChainID uint64) error {
	query := `
DELETE FROM events
WHERE block_id >= ? AND chain_id = ? AND dest_chain_id = ?`

	return db.Table("events").Exec(query, blockID, srcChainID, destChainID).Error
}

// GetLatestBlockID get latest block id
func (r *EventRepository) FindLatestBlockID(
	db *gorm.DB,
	event string,
	srcChainID uint64,
	destChainID uint64,
) (uint64, error) {
	q := `SELECT COALESCE(MAX(emitted_block_id), 0)
	FROM events WHERE chain_id = ? AND dest_chain_id = ? AND event = ?`

	var b uint64

	if err := db.Table("events").Raw(q, srcChainID, destChainID, event).Scan(&b).Error; err != nil {
		return 0, err
	}

	return b, nil
}
