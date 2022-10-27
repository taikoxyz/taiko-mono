package repo

import (
	"math/big"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"gopkg.in/go-playground/assert.v1"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func Test_NewService(t *testing.T) {
	tests := []struct {
		name    string
		db      *gorm.DB
		wantErr error
	}{
		{
			"success",
			&gorm.DB{},
			nil,
		},
		{
			"noDb",
			nil,
			relayer.ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewEventRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func Test_Save(t *testing.T) {
	tests := []struct {
		name    string
		opts    relayer.SaveEventOpts
		wantErr error
	}{
		{
			"success",
			relayer.SaveEventOpts{
				Name:    "test",
				ChainID: big.NewInt(1),
				Data:    "{\"data\":\"something\"}",
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sqlDB, mock, err := sqlmock.New()
			mock.ExpectQuery("SELECT VERSION()")
			assert.Equal(t, nil, err)
			db, err := gorm.Open(mysql.New(mysql.Config{
				DSN:        "sqlmock_db_0",
				Conn:       sqlDB,
				DriverName: "mysql",
			}), &gorm.Config{})
			r, _ := NewEventRepository(db)

			_, err = r.Save(tt.opts)
			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, nil, mock.ExpectationsWereMet())
		})
	}
}
