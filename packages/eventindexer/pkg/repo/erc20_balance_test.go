package repo

import (
	"context"
	"errors"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"gorm.io/gorm/clause"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func Test_NewERC20BalanceRepo(t *testing.T) {
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
			_, err := NewERC20BalanceRepository(tt.db)
			if !errors.Is(err, tt.wantErr) {
				t.Errorf("NewERC20BalanceRepository() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
		})
	}
}

func TestIntegration_ERC20Balance_Increase_And_Decrease(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	ERC20BalanceRepo, err := NewERC20BalanceRepository(db)
	assert.Equal(t, nil, err)

	pk, _ := ERC20BalanceRepo.CreateMetadata(context.Background(), 1, "0x123", "SYMBOL", 18)

	bal1, _, err := ERC20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindERC20, 1),
		eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         1,
			Address:         "0x123",
			ContractAddress: "0x123",
			Amount:          "1",
		}, eventindexer.UpdateERC20BalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal1)

	bal2, _, err := ERC20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindERC20, 2),
		eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         1,
			Address:         "0x123",
			ContractAddress: "0x123456",
			Amount:          "2",
		}, eventindexer.UpdateERC20BalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal2)

	tests := []struct {
		name         string
		increaseOpts eventindexer.UpdateERC20BalanceOpts
		decreaseOpts eventindexer.UpdateERC20BalanceOpts
		wantErr      error
	}{
		{
			"success",
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123456789",
				Amount:          "1",
			},
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123",
				Amount:          "1",
			},
			nil,
		},
		{
			"one left",
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123456789",
				Amount:          "1",
			},
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123456",
				Amount:          "1",
			},
			nil,
		},
	}

	for i, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := ERC20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
				testRef(eventindexer.TransferKindERC20, uint(10+i)), tt.increaseOpts, tt.decreaseOpts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_ERC20Balance_FindByAddress(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	ERC20BalanceRepo, err := NewERC20BalanceRepository(db)
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
			_, err := ERC20BalanceRepo.FindByAddress(
				context.Background(),
				get,
				tt.address,
				tt.chainID)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_ERC20Balance_RestartReplayDoesNotDoubleCount(t *testing.T) {
	database, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	erc20BalanceRepo, err := NewERC20BalanceRepository(database)
	assert.Equal(t, nil, err)

	pk, err := erc20BalanceRepo.CreateMetadata(context.Background(), 1, "0xerc20", "SYMBOL", 18)
	assert.Equal(t, nil, err)

	opts := func(address string) eventindexer.UpdateERC20BalanceOpts {
		return eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         1,
			Address:         address,
			ContractAddress: "0xerc20",
			Amount:          "100",
		}
	}

	amountOf := func(address string) (string, bool) {
		var b eventindexer.ERC20Balance

		if err := database.GormDB().
			Where("address = ?", address).
			Where("contract_address = ?", "0xerc20").
			First(&b).Error; err != nil {
			return "", false
		}

		return b.Amount, true
	}

	// mint to alice
	_, _, err = erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		testRef(eventindexer.TransferKindERC20, 1), opts("0xalice"), eventindexer.UpdateERC20BalanceOpts{})
	assert.Equal(t, nil, err)

	// alice -> bob
	transferRef := testRef(eventindexer.TransferKindERC20, 2)

	_, _, err = erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		transferRef, opts("0xbob"), opts("0xalice"))
	assert.Equal(t, nil, err)

	amount, ok := amountOf("0xbob")
	assert.True(t, ok)
	assert.Equal(t, "100", amount)

	// restart replay of the same log must not credit bob twice
	increased, decreased, err := erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		transferRef, opts("0xbob"), opts("0xalice"))
	assert.Equal(t, nil, err)
	assert.Nil(t, increased)
	assert.Nil(t, decreased)

	amount, ok = amountOf("0xbob")
	assert.True(t, ok)
	assert.Equal(t, "100", amount)
}

// waitForLockWaiters blocks until at least n transactions are queued on a lock.
//
// It is what makes the concurrency test below deterministic. Sleeping and hoping
// both goroutines have reached the balance row would make the test a coin flip;
// asking the server how many transactions are waiting is not.
func waitForLockWaiters(t *testing.T, d db.DB, n int64) {
	t.Helper()

	deadline := time.Now().Add(30 * time.Second)

	for {
		var waiting int64

		err := d.GormDB().Raw("SELECT COUNT(*) FROM performance_schema.data_lock_waits").Scan(&waiting).Error
		if err != nil {
			// performance_schema unavailable: fall back to giving the goroutines
			// time to reach the row, which is weaker but still exercises the race
			t.Logf("data_lock_waits unavailable (%v), falling back to a fixed wait", err)

			time.Sleep(2 * time.Second)

			return
		}

		if waiting >= n {
			return
		}

		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting for %d lock waiters, saw %d", n, waiting)
		}

		time.Sleep(50 * time.Millisecond)
	}
}

// TestIntegration_ERC20Balance_ConcurrentTransfers covers two different transfer
// logs touching the same balance, which is what indexERC20Transfers does: it
// runs one goroutine per log and each of them calls
// IncreaseAndDecreaseBalancesInTx independently.
//
// processed_transfer_logs does not cover this. It makes one log replayed twice a
// no-op; two distinct logs crediting one account is a different race, and the
// read-modify-write in increaseBalanceInDB loses one of them.
func TestIntegration_ERC20Balance_ConcurrentTransfers(t *testing.T) {
	// closeFn, not close: the subtests below use close() to release the
	// goroutines they start at the same moment
	database, closeFn, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer closeFn()

	erc20BalanceRepo, err := NewERC20BalanceRepository(database)
	assert.Equal(t, nil, err)

	pk, err := erc20BalanceRepo.CreateMetadata(context.Background(), 1, "0xerc20", "SYMBOL", 18)
	assert.Equal(t, nil, err)

	opts := func(address string, amount string) eventindexer.UpdateERC20BalanceOpts {
		return eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         1,
			Address:         address,
			ContractAddress: "0xerc20",
			Amount:          amount,
		}
	}

	balancesOf := func(address string) []eventindexer.ERC20Balance {
		var balances []eventindexer.ERC20Balance

		assert.Equal(t, nil, database.GormDB().
			Where("address = ?", address).
			Where("contract_address = ?", "0xerc20").
			Find(&balances).Error)

		return balances
	}

	t.Run("two concurrent increases both apply", func(t *testing.T) {
		// bob starts at 100
		_, _, err = erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
			testRef(eventindexer.TransferKindERC20, 1), opts("0xbob", "100"),
			eventindexer.UpdateERC20BalanceOpts{})
		assert.Equal(t, nil, err)

		// Hold bob's row so that both transfers below have read it before either
		// can write. Without the lock in findERC20BalanceForUpdate their reads are
		// snapshot reads that never block, so both compute from 100 and whichever
		// writes last decides the balance: 110 or 120, never 130. With it they
		// queue on the row lock and the second reads what the first committed.
		blocker := database.GormDB().Begin()

		var locked eventindexer.ERC20Balance

		assert.Equal(t, nil, blocker.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("address = ?", "0xbob").
			Where("contract_address = ?", "0xerc20").
			First(&locked).Error)

		var wg sync.WaitGroup

		wg.Add(2)

		for i, amount := range []string{"10", "20"} {
			go func(i int, amount string) {
				defer wg.Done()

				_, _, err := erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
					testRef(eventindexer.TransferKindERC20, uint(2+i)), opts("0xbob", amount),
					eventindexer.UpdateERC20BalanceOpts{})
				assert.Equal(t, nil, err)
			}(i, amount)
		}

		waitForLockWaiters(t, database, 2)

		assert.Equal(t, nil, blocker.Commit().Error)

		wg.Wait()

		balances := balancesOf("0xbob")

		assert.Equal(t, 1, len(balances))
		assert.Equal(t, "130", balances[0].Amount)
	})

	t.Run("concurrent first credits create one row", func(t *testing.T) {
		// carol has no balance row yet, so every one of these tries to insert
		const transfers = 8

		start := make(chan struct{})

		var wg sync.WaitGroup

		wg.Add(transfers)

		for i := 0; i < transfers; i++ {
			go func(i int) {
				defer wg.Done()

				<-start

				_, _, err := erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
					testRef(eventindexer.TransferKindERC20, uint(100+i)), opts("0xcarol", "10"),
					eventindexer.UpdateERC20BalanceOpts{})
				assert.Equal(t, nil, err)
			}(i)
		}

		close(start)

		wg.Wait()

		// one row holding every credit, not eight rows holding one each
		balances := balancesOf("0xcarol")

		assert.Equal(t, 1, len(balances))
		assert.Equal(t, "80", balances[0].Amount)
	})

	t.Run("a credit that races a draining transfer still lands", func(t *testing.T) {
		// frank has a row, and a concurrent transfer drains it to zero and
		// deletes it while this credit is in flight
		_, _, err = erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
			testRef(eventindexer.TransferKindERC20, 200), opts("0xfrank", "10"),
			eventindexer.UpdateERC20BalanceOpts{})
		assert.Equal(t, nil, err)

		drainer := database.GormDB().Begin()

		assert.Equal(t, nil, drainer.
			Where("address = ?", "0xfrank").
			Where("contract_address = ?", "0xerc20").
			Delete(&eventindexer.ERC20Balance{}).Error)

		var wg sync.WaitGroup

		wg.Add(1)

		go func() {
			defer wg.Done()

			// the existence probe sees frank's row and fixes this transaction's
			// snapshot; the locking read then waits for the delete to commit
			_, _, err := erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
				testRef(eventindexer.TransferKindERC20, 201), opts("0xfrank", "5"),
				eventindexer.UpdateERC20BalanceOpts{})
			assert.Equal(t, nil, err)
		}()

		waitForLockWaiters(t, database, 1)

		assert.Equal(t, nil, drainer.Commit().Error)

		wg.Wait()

		// Re-probing after the locking read missed would keep finding the
		// deleted row in the snapshot, exhaust every attempt, and fail the whole
		// batch. The credit has to land as a fresh row instead.
		balances := balancesOf("0xfrank")

		assert.Equal(t, 1, len(balances))
		assert.Equal(t, "5", balances[0].Amount)
	})

	t.Run("one balance per account, token and chain", func(t *testing.T) {
		insert := func(address string, chainID int64) error {
			return database.GormDB().Exec(
				`INSERT INTO erc20_balances (erc20_metadata_id, chain_id, address, amount, contract_address)
				 VALUES (?, ?, ?, '1', '0xerc20')`, pk, chainID, address).Error
		}

		assert.Equal(t, nil, insert("0xdave", 1))

		// the logical identity is (contract_address, address, chain_id), so the
		// storage engine has to refuse a second row for it
		assert.NotNil(t, insert("0xdave", 1))

		// and it stays scoped: a different account, or the same account on
		// another chain, is a different balance
		assert.Equal(t, nil, insert("0xerin", 1))
		assert.Equal(t, nil, insert("0xdave", 2))
	})
}
