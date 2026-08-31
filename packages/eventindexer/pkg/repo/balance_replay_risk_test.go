package repo

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

// seedResumeBlock writes the event whose emitted_block_id the cursor rewinds
// from, at a chosen block time.
func seedResumeBlock(t *testing.T, d db.DB, chainID int64, at time.Time) {
	t.Helper()

	err := d.GormDB().Exec(
		`INSERT INTO events (name, event, chain_id, data, emitted_block_id, transacted_at)
		 VALUES ('MessageSent', 'MessageSent', ?, '{}', 100, ?)`,
		chainID, at,
	).Error
	assert.Equal(t, nil, err)
}

func seedNFTBalance(t *testing.T, d db.DB, chainID int64, updatedAt time.Time) {
	t.Helper()

	err := d.GormDB().Exec(
		`INSERT INTO nft_balances (chain_id, address, amount, contract_address, contract_type, token_id, updated_at)
		 VALUES (?, '0xholder', 1, '0xnft', 'ERC721', 1, ?)`,
		chainID, updatedAt,
	).Error
	assert.Equal(t, nil, err)
}

func TestIntegration_UnclaimedBalanceReplayRisk(t *testing.T) {
	var (
		old    = time.Now().Add(-90 * 24 * time.Hour).UTC().Truncate(time.Second)
		resume = time.Now().Add(-2 * time.Hour).UTC().Truncate(time.Second)
		recent = time.Now().Add(-time.Minute).UTC().Truncate(time.Second)
	)

	tests := []struct {
		name   string
		seed   func(t *testing.T, d db.DB)
		kind   string
		want   bool
		wantOK bool
	}{
		{
			"nothing indexed yet",
			func(t *testing.T, d db.DB) {},
			eventindexer.TransferKindNFT,
			false,
			true,
		},
		{
			"balances but no events, cursor starts at the fork height",
			func(t *testing.T, d db.DB) { seedNFTBalance(t, d, 1, recent) },
			eventindexer.TransferKindNFT,
			false,
			true,
		},
		{
			// balance indexing was switched off long ago and is only now being
			// re-enabled: the replay range is newer than anything already written
			"balances predate the block being resumed from",
			func(t *testing.T, d db.DB) {
				seedNFTBalance(t, d, 1, old)
				seedResumeBlock(t, d, 1, resume)
			},
			eventindexer.TransferKindNFT,
			false,
			true,
		},
		{
			// a pre-claim process was writing balances inside the replay range
			"balances written at or after the block being resumed from",
			func(t *testing.T, d db.DB) {
				seedNFTBalance(t, d, 1, recent)
				seedResumeBlock(t, d, 1, resume)
			},
			eventindexer.TransferKindNFT,
			true,
			true,
		},
		{
			"a claim for this chain and kind clears the risk",
			func(t *testing.T, d db.DB) {
				seedNFTBalance(t, d, 1, recent)
				seedResumeBlock(t, d, 1, resume)

				applied, err := markTransferLogApplied(context.Background(), d.GormDB(),
					testRef(eventindexer.TransferKindNFT, 1))
				assert.Equal(t, nil, err)
				assert.True(t, applied)
			},
			eventindexer.TransferKindNFT,
			false,
			true,
		},
		{
			// claims are scoped per kind, an erc20 claim says nothing about nfts
			"a claim for the other kind does not clear the risk",
			func(t *testing.T, d db.DB) {
				seedNFTBalance(t, d, 1, recent)
				seedResumeBlock(t, d, 1, resume)

				applied, err := markTransferLogApplied(context.Background(), d.GormDB(),
					testRef(eventindexer.TransferKindERC20, 1))
				assert.Equal(t, nil, err)
				assert.True(t, applied)
			},
			eventindexer.TransferKindNFT,
			true,
			true,
		},
		{
			"unknown kind",
			func(t *testing.T, d db.DB) {},
			"erc721",
			false,
			false,
		},
	}

	database, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			truncate(t, database)
			tt.seed(t, database)

			got, err := UnclaimedBalanceReplayRisk(context.Background(), database, 1, tt.kind)
			if !tt.wantOK {
				assert.NotNil(t, err)
				return
			}

			assert.Equal(t, nil, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func truncate(t *testing.T, d db.DB) {
	t.Helper()

	for _, table := range []string{"events", "nft_balances", "processed_transfer_logs"} {
		assert.Equal(t, nil, d.GormDB().Session(&gorm.Session{AllowGlobalUpdate: true}).
			Exec("DELETE FROM "+table).Error)
	}
}
