package repo

import (
	"testing"

	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
	"gopkg.in/go-playground/assert.v1"
)

func Test_NewSignedBlockRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      DB
		wantErr error
	}{
		{
			"success",
			&db.DB{},
			nil,
		},
		{
			"noDb",
			nil,
			ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewSignedBlockRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_SignedBlock_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	SignedBlockRepo, err := NewSignedBlockRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		opts    guardianproverhealthcheck.SaveSignedBlockOpts
		wantErr error
	}{
		{
			"success",
			guardianproverhealthcheck.SaveSignedBlockOpts{
				GuardianProverID: 1,
				RecoveredAddress: "0x123",
				Signature:        "0x456",
				BlockID:          1,
				BlockHash:        "0x987",
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err = SignedBlockRepo.Save(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
