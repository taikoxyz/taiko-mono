package mocks

import (
	"database/sql"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/mock"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type MockDB struct {
	mock.Mock
	gormDB *gorm.DB
}

func (m *MockDB) DB() (*sql.DB, error) {
	args := m.Called()
	return args.Get(0).(*sql.DB), args.Error(1)
}

func (m *MockDB) GormDB() *gorm.DB {
	args := m.Called()
	return args.Get(0).(*gorm.DB)
}

func (db *MockDB) Begin() *gorm.DB {
	args := db.Called()
	return args.Get(0).(*gorm.DB)
}

func (db *MockDB) Commit() error {
	args := db.Called()
	return args.Error(0)
}

func (db *MockDB) Rollback() error {
	args := db.Called()
	return args.Error(0)
}

func NewMockDB(t *testing.T) (*MockDB, sqlmock.Sqlmock, *gorm.DB, func()) {
	sqlDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("newMockDB: %v", err)
	}

	mock.ExpectQuery("select sqlite_version()").
		WillReturnRows(sqlmock.NewRows([]string{"version"}).
			AddRow("3.31.1"))

	gormDB, err := gorm.Open(sqlite.Dialector{Conn: sqlDB}, &gorm.Config{})
	if err != nil {
		t.Fatalf("newMockDB: %v", err)
	}

	mockDB := &MockDB{gormDB: gormDB}
	closeDB := func() { sqlDB.Close() }

	return mockDB, mock, gormDB, closeDB
}
