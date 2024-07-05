package repo

import (
	"context"
	"net/http"
	"testing"

	"gopkg.in/go-playground/assert.v1"

	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
)

func Test_NewStartupRepo(t *testing.T) {
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
			_, err := NewStartupRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Startup_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	startupRepo, err := NewStartupRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		opts    guardianproverhealthcheck.SaveStartupOpts
		wantErr error
	}{
		{
			"success",
			guardianproverhealthcheck.SaveStartupOpts{
				GuardianProverID:      1,
				GuardianProverAddress: "0x123",
				Revision:              "asdf",
				GuardianVersion:       "v1.0.0",
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err = startupRepo.Save(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Startup_GetByGuardianProverID(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	startupRepo, err := NewStartupRepository(db)
	assert.Equal(t, nil, err)

	err = startupRepo.Save(guardianproverhealthcheck.SaveStartupOpts{
		GuardianProverID:      1,
		GuardianProverAddress: "0x123",
		Revision:              "asdf",
		GuardianVersion:       "v1.0.0",
		L1NodeVersion:         "v0.1.0",
		L2NodeVersion:         "v0.0.1",
	})

	assert.Equal(t, nil, err)

	err = startupRepo.Save(guardianproverhealthcheck.SaveStartupOpts{
		GuardianProverID:      1,
		GuardianProverAddress: "0x123",
		Revision:              "zxxc",
		GuardianVersion:       "v1.0.1",
		L1NodeVersion:         "v0.1.0",
		L2NodeVersion:         "v0.0.1",
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name    string
		address string
		wantErr error
	}{
		{
			"success",
			"0x123",
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, err := http.NewRequest(http.MethodGet, "/signedBlock", nil)
			assert.Equal(t, nil, err)

			page, err := startupRepo.GetByGuardianProverAddress(context.Background(), req, tt.address)
			assert.Equal(t, nil, err)

			assert.Equal(t, page.Total, int64(2))
		})
	}
}
