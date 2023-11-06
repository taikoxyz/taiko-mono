package mock

import (
	"database/sql"

	"gorm.io/gorm"
)

type DB struct {
}

func (db *DB) DB() (*sql.DB, error) {
	return &sql.DB{}, nil
}

func (db *DB) GormDB() *gorm.DB {
	return &gorm.DB{}
}
