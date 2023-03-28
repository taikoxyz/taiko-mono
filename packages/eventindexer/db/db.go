package db

import (
	"database/sql"

	"gorm.io/gorm"
)

type DB struct {
	gormdb *gorm.DB
}

func (db *DB) DB() (*sql.DB, error) {
	return db.gormdb.DB()
}

func (db *DB) GormDB() *gorm.DB {
	return db.gormdb
}

func New(gormdb *gorm.DB) *DB {
	return &DB{
		gormdb: gormdb,
	}
}
