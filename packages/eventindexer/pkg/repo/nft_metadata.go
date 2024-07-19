package repo

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/pkg/errors"
	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

type NFTMetadataRepository struct {
	db db.DB
}

func NewNFTMetadataRepository(dbHandler db.DB) (*NFTMetadataRepository, error) {
	if dbHandler == nil {
		return nil, db.ErrNoDB
	}

	return &NFTMetadataRepository{
		db: dbHandler,
	}, nil
}

func (r *NFTMetadataRepository) SaveNFTMetadata(
	ctx context.Context,
	metadata *eventindexer.NFTMetadata,
) (*eventindexer.NFTMetadata, error) {
	existingMetadata, err := r.GetNFTMetadata(ctx, metadata.ContractAddress, metadata.TokenID, metadata.ChainID)
	if err != nil {
		return nil, errors.Wrap(err, "failed to check existing metadata")
	}

	if existingMetadata != nil {
		return existingMetadata, nil
	}

	err = r.db.GormDB().Save(metadata).Error
	if err != nil {
		return nil, errors.Wrap(err, "r.db.Save")
	}

	return metadata, nil
}

func (r *NFTMetadataRepository) GetNFTMetadata(
	ctx context.Context,
	contractAddress string,
	tokenID int64,
	chainID int64,
) (*eventindexer.NFTMetadata, error) {
	metadata := &eventindexer.NFTMetadata{}

	err := r.db.GormDB().
		Where("contract_address = ?", contractAddress).
		Where("token_id = ?", tokenID).
		Where("chain_id = ?", chainID).
		First(metadata).
		Error

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}

		return nil, errors.Wrap(err, "r.db.First")
	}

	return metadata, nil
}

func (r *NFTMetadataRepository) FindByContractAddress(
	ctx context.Context,
	req *http.Request,
	contractAddress string,
) (paginate.Page, error) {
	pg := paginate.New(&paginate.Config{
		DefaultSize: 100,
	})

	q := r.db.GormDB().
		Raw("SELECT * FROM nft_metadata WHERE contract_address = ?", contractAddress)

	reqCtx := pg.With(q)

	page := reqCtx.Request(req).Response(&[]eventindexer.NFTMetadata{})

	return page, nil
}
