package repo

import (
	"context"
	"net/http"
	"testing"

	"gopkg.in/go-playground/assert.v1"

	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
)

func Test_NewHealthCheckRepo(t *testing.T) {
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
			_, err := NewHealthCheckRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_HealthCheck_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	healthCheckRepo, err := NewHealthCheckRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		opts    guardianproverhealthcheck.SaveHealthCheckOpts
		wantErr error
	}{
		{
			"success",
			guardianproverhealthcheck.SaveHealthCheckOpts{
				GuardianProverID: 1,
				Alive:            true,
				ExpectedAddress:  "0x123",
				RecoveredAddress: "0x123",
				SignedResponse:   "0x123456",
				LatestL1Block:    5,
				LatestL2Block:    7,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err = healthCheckRepo.Save(context.Background(), &tt.opts)
			assert.Equal(t, tt.wantErr, err)

			req, err := http.NewRequest(http.MethodGet, "/healtcheck", nil)
			assert.Equal(t, nil, err)

			page, err := healthCheckRepo.Get(context.Background(), req)
			assert.Equal(t, nil, err)
			assert.Equal(t, page.Size, int64(100))
			assert.Equal(t, page.Total, int64(1))
		})
	}
}

func TestIntegration_HealthCheck_UptimeByGuardianProverId(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	healthCheckRepo, err := NewHealthCheckRepository(db)

	assert.Equal(t, nil, err)

	err = healthCheckRepo.Save(context.Background(), &guardianproverhealthcheck.SaveHealthCheckOpts{
		GuardianProverID: 1,
		Alive:            true,
		ExpectedAddress:  "0x123",
		RecoveredAddress: "0x123",
		SignedResponse:   "0x123456",
		LatestL1Block:    5,
		LatestL2Block:    7,
	})

	assert.Equal(t, err, nil)

	err = healthCheckRepo.Save(context.Background(), &guardianproverhealthcheck.SaveHealthCheckOpts{
		GuardianProverID: 1,
		Alive:            true,
		ExpectedAddress:  "0x123",
		RecoveredAddress: "0x123",
		SignedResponse:   "0x123456",
		LatestL1Block:    5,
		LatestL2Block:    7,
	})

	assert.Equal(t, err, nil)

	tests := []struct {
		name       string
		address    string
		wantCount  int
		wantUptime float64
		wantErr    error
	}{
		{
			"success",
			"0x123",
			2,
			(float64(2) / 7200) * 100,
			nil,
		},
		{
			"successNoHealthChecks",
			"0xfake",
			0,
			float64(0),
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uptime, count, err := healthCheckRepo.GetUptimeByGuardianProverAddress(context.Background(), tt.address)

			assert.Equal(t, err, tt.wantErr)

			assert.Equal(t, tt.wantUptime, uptime)

			assert.Equal(t, tt.wantCount, count)
		})
	}
}
