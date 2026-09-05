package repo

import (
	"context"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// testRef returns a distinct TransferLogRef per n, standing in for the
// (txHash, logIndex) identity a real log carries. Two calls with the same n
// represent the same log being applied twice, which is what a restart replay
// does.
func testRef(kind string, n uint) eventindexer.TransferLogRef {
	return eventindexer.TransferLogRef{
		ChainID:  1,
		TxHash:   fmt.Sprintf("0x%064x", n),
		LogIndex: n,
		Kind:     kind,
	}
}

func TestIntegration_TransferLog_ReplayDetectedWithClientFoundRows(t *testing.T) {
	// CLIENT_FOUND_ROWS makes a no-op UPDATE report one found row instead of zero
	// changed rows. The claim must not depend on that flag being off:
	// clause.OnConflict{DoNothing: true} is rewritten by gorm's MySQL dialector to
	// ON DUPLICATE KEY UPDATE id=id, which under this DSN reported one affected
	// row, so every replay read as new and was applied a second time.
	database, close, err := testMysql(t, "clientFoundRows=true")
	assert.Equal(t, nil, err)

	defer close()

	claimRef := testRef(eventindexer.TransferKindNFT, 1)

	applied, err := markTransferLogApplied(context.Background(), database.GormDB(), claimRef)
	assert.Equal(t, nil, err)
	assert.True(t, applied)

	reapplied, err := markTransferLogApplied(context.Background(), database.GormDB(), claimRef)
	assert.Equal(t, nil, err)
	assert.False(t, reapplied)

	// and end to end: a replayed transfer must leave the balance alone
	nftBalanceRepo, err := NewNFTBalanceRepository(database)
	assert.Equal(t, nil, err)

	opts := eventindexer.UpdateNFTBalanceOpts{
		ChainID:         1,
		Address:         "0xbob",
		TokenID:         1,
		ContractAddress: "0xnftcontract",
		ContractType:    "ERC721",
		Amount:          1,
	}

	transferRef := testRef(eventindexer.TransferKindNFT, 2)

	bal, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		transferRef, opts, eventindexer.UpdateNFTBalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal)
	assert.Equal(t, int64(1), bal.Amount)

	increased, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		transferRef, opts, eventindexer.UpdateNFTBalanceOpts{})
	assert.Equal(t, nil, err)
	assert.Nil(t, increased)

	var b eventindexer.NFTBalance

	err = database.GormDB().Where("address = ?", "0xbob").First(&b).Error
	assert.Equal(t, nil, err)
	assert.Equal(t, int64(1), b.Amount)
}
