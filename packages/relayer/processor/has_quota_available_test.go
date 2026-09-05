package processor

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// stubQuotaManager answers with whatever the test sets, which the shared mock cannot do.
type stubQuotaManager struct {
	available    *big.Int
	availableErr error
	period       *big.Int
	periodErr    error
	periodCalls  int
}

func (q *stubQuotaManager) AvailableQuota(
	_ *bind.CallOpts,
	_ common.Address,
	_ *big.Int,
) (*big.Int, error) {
	if q.availableErr != nil {
		return nil, q.availableErr
	}

	return q.available, nil
}

func (q *stubQuotaManager) QuotaPeriod(_ *bind.CallOpts) (*big.Int, error) {
	q.periodCalls++

	if q.periodErr != nil {
		return nil, q.periodErr
	}

	return q.period, nil
}

func Test_hasQuotaAvailable(t *testing.T) {
	tests := []struct {
		name         string
		quota        *stubQuotaManager
		msgValue     *big.Int
		want         bool
		wantWaitFor  uint64
		wantErr      string
		wantPeriodOp int
	}{
		{
			name:     "quota above the message value",
			quota:    &stubQuotaManager{available: big.NewInt(1000), period: big.NewInt(60)},
			msgValue: big.NewInt(999),
			want:     true,
		},
		{
			// Cmp is -1 only when strictly below, so a message that exactly spends the remaining
			// quota still goes through rather than waiting a whole period for nothing.
			name:     "quota exactly equal to the message value",
			quota:    &stubQuotaManager{available: big.NewInt(1000), period: big.NewInt(60)},
			msgValue: big.NewInt(1000),
			want:     true,
		},
		{
			name:         "quota below the message value",
			quota:        &stubQuotaManager{available: big.NewInt(10), period: big.NewInt(3600)},
			msgValue:     big.NewInt(11),
			want:         false,
			wantWaitFor:  3600,
			wantPeriodOp: 1,
		},
		{
			// An unreadable quota must not be treated as "plenty": that would send a message the
			// bridge is about to reject.
			name:     "the quota read fails",
			quota:    &stubQuotaManager{availableErr: errors.New("call reverted")},
			msgValue: big.NewInt(1),
			wantErr:  "call reverted",
		},
		{
			name: "the period read fails",
			quota: &stubQuotaManager{
				available: big.NewInt(0),
				periodErr: errors.New("no period"),
			},
			msgValue:     big.NewInt(1),
			wantErr:      "no period",
			wantPeriodOp: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := newTestProcessor(false)
			p.destQuotaManager = tt.quota

			ok, waitFor, err := p.hasQuotaAvailable(
				context.Background(),
				common.HexToAddress("0x0"),
				tt.msgValue,
			)

			if tt.wantErr != "" {
				require.ErrorContains(t, err, tt.wantErr)
				assert.False(t, ok)
				assert.Equal(t, uint64(0), waitFor)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.want, ok)
				assert.Equal(t, tt.wantWaitFor, waitFor)
			}

			// The period is only worth a second call when the message actually has to wait.
			assert.Equal(t, tt.wantPeriodOp, tt.quota.periodCalls)
		})
	}
}
