package repo

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func Test_NewNFTBalanceRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      db.DB
		wantErr error
	}{
		{
			"success",
			&db.Database{},
			nil,
		},
		{
			"noDb",
			nil,
			db.ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewNFTBalanceRepository(tt.db)
			if err != tt.wantErr {
				t.Errorf("NewNFTBalanceRepository() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
		})
	}
}

func TestIntegration_NFTBalance_Increase_And_Decrease(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(db)
	assert.Equal(t, nil, err)

	bal1, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindNFT, 1),
		eventindexer.UpdateNFTBalanceOpts{
			ChainID:         1,
			Address:         "0x123",
			TokenID:         1,
			ContractAddress: "0x123",
			ContractType:    "ERC721",
			Amount:          1,
		}, eventindexer.UpdateNFTBalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal1)

	bal2, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindNFT, 2),
		eventindexer.UpdateNFTBalanceOpts{
			ChainID:         1,
			Address:         "0x123",
			TokenID:         1,
			ContractAddress: "0x123456",
			ContractType:    "ERC721",
			Amount:          2,
		}, eventindexer.UpdateNFTBalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal2)

	tests := []struct {
		name         string
		increaseOpts eventindexer.UpdateNFTBalanceOpts
		decreaseOpts eventindexer.UpdateNFTBalanceOpts
		wantErr      error
	}{
		{
			"success",
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123456789",
				ContractType:    "ERC721",
				Amount:          1,
			},
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123",
				ContractType:    "ERC721",
				Amount:          1,
			},
			nil,
		},
		{
			"one left",
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123456789",
				ContractType:    "ERC721",
				Amount:          1,
			},
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123456",
				ContractType:    "ERC721",
				Amount:          1,
			},
			nil,
		},
	}

	for i, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
				testRef(eventindexer.TransferKindNFT, uint(10+i)), tt.increaseOpts, tt.decreaseOpts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_NFTBalance_FindByAddress(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(db)
	assert.Equal(t, nil, err)

	tests := []struct {
		name    string
		address string
		chainID string
		wantErr error
	}{
		{
			"success",
			"0x123",
			"1",
			nil,
		},
	}

	get, err := http.NewRequest("GET", "/", nil)
	assert.Equal(t, nil, err)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := nftBalanceRepo.FindByAddress(
				context.Background(),
				get,
				tt.address,
				tt.chainID)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_NFTBalance_RestartReplayDoesNotDoubleCount(t *testing.T) {
	database, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(database)
	assert.Equal(t, nil, err)

	const (
		contract = "0xnftcontract"
		alice    = "0xalice"
		bob      = "0xbob"
		carol    = "0xcarol"
	)

	opts := func(address string) eventindexer.UpdateNFTBalanceOpts {
		return eventindexer.UpdateNFTBalanceOpts{
			ChainID:         1,
			Address:         address,
			TokenID:         1,
			ContractAddress: contract,
			ContractType:    "ERC721",
			Amount:          1,
		}
	}

	amountOf := func(address string) (int64, bool) {
		var b eventindexer.NFTBalance

		if err := database.GormDB().
			Where("address = ?", address).
			Where("token_id = ?", 1).
			Where("contract_address = ?", contract).
			First(&b).Error; err != nil {
			return 0, false
		}

		return b.Amount, true
	}

	// mint to alice
	_, _, err = nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindNFT, 1), opts(alice), eventindexer.UpdateNFTBalanceOpts{})
	assert.Equal(t, nil, err)

	// alice -> bob
	transferRef := testRef(eventindexer.TransferKindNFT, 2)

	_, _, err = nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		transferRef, opts(bob), opts(alice))
	assert.Equal(t, nil, err)

	amount, ok := amountOf(bob)
	assert.True(t, ok)
	assert.Equal(t, int64(1), amount)

	_, aliceHasRow := amountOf(alice)
	assert.False(t, aliceHasRow)

	// The indexer restarts and re-processes the block holding alice -> bob.
	// Without the processed_transfer_logs claim this incremented bob to 2 and
	// could not decrement alice's already-deleted row.
	increased, decreased, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		transferRef, opts(bob), opts(alice))
	assert.Equal(t, nil, err)
	assert.Nil(t, increased)
	assert.Nil(t, decreased)

	amount, ok = amountOf(bob)
	assert.True(t, ok)
	assert.Equal(t, int64(1), amount)

	// A genuinely new log for the same token must still be applied, so the claim
	// cannot be over-blocking.
	_, _, err = nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindNFT, 3), opts(carol), opts(bob))
	assert.Equal(t, nil, err)

	amount, ok = amountOf(carol)
	assert.True(t, ok)
	assert.Equal(t, int64(1), amount)

	_, bobHasRow := amountOf(bob)
	assert.False(t, bobHasRow)
}

func TestIntegration_NFTBalance_BatchIndexSeparatesUnitsOfOneLog(t *testing.T) {
	database, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(database)
	assert.Equal(t, nil, err)

	// One ERC1155 TransferBatch log carries several token ids. They share a
	// (txHash, logIndex) and are told apart only by BatchIndex, so all of them
	// must still be applied.
	ref := func(batchIndex uint) eventindexer.TransferLogRef {
		return eventindexer.TransferLogRef{
			ChainID:    1,
			TxHash:     "0xbatch",
			LogIndex:   7,
			BatchIndex: batchIndex,
			Kind:       eventindexer.TransferKindNFT,
		}
	}

	opts := func(tokenID int64) eventindexer.UpdateNFTBalanceOpts {
		return eventindexer.UpdateNFTBalanceOpts{
			ChainID:         1,
			Address:         "0xholder",
			TokenID:         tokenID,
			ContractAddress: "0x1155",
			ContractType:    "ERC1155",
			Amount:          3,
		}
	}

	for i := range 2 {
		bal, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
			ref(uint(i)), opts(int64(i+1)), eventindexer.UpdateNFTBalanceOpts{})
		assert.Equal(t, nil, err)
		assert.NotNil(t, bal)
		assert.Equal(t, int64(3), bal.Amount)
	}

	// replaying the whole log leaves both units untouched
	for i := range 2 {
		increased, _, err := nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
			ref(uint(i)), opts(int64(i+1)), eventindexer.UpdateNFTBalanceOpts{})
		assert.Equal(t, nil, err)
		assert.Nil(t, increased)
	}

	var balances []eventindexer.NFTBalance

	err = database.GormDB().Where("address = ?", "0xholder").Find(&balances).Error
	assert.Equal(t, nil, err)
	assert.Equal(t, 2, len(balances))

	for _, b := range balances {
		assert.Equal(t, int64(3), b.Amount)
	}
}
