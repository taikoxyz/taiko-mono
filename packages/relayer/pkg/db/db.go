package db

import (
	"fmt"
	"time"

	"database/sql"
	"github.com/cyberhorsey/errors"
	"gorm.io/gorm"
)

var (
	ErrNoDB = errors.Validation.NewWithKeyAndDetail("ERR_NO_DB", "no db")
)

// DB is a local interface that lets us narrow down a database type for testing.
type DB interface {
	DB() (*sql.DB, error)
	GormDB() *gorm.DB
}

type Database struct {
	gormdb *gorm.DB
}

func (db *Database) DB() (*sql.DB, error) {
	return db.gormdb.DB()
}

func (db *Database) GormDB() *gorm.DB {
	return db.gormdb
}

func New(gormdb *gorm.DB) DB {
	return &Database{
		gormdb: gormdb,
	}
}

type DBConnectionOpts struct {
	Name            string
	Password        string
	Host            string
	Database        string
	MaxIdleConns    uint64
	MaxOpenConns    uint64
	MaxConnLifetime uint64
	OpenFunc        func(dsn string) (DB, error)
}

func OpenDBConnection(opts DBConnectionOpts) (DB, error) {
	dsn := ""
	if opts.Password == "" {
		dsn = fmt.Sprintf(
			"%v@tcp(%v)/%v?charset=utf8mb4&parseTime=True&loc=%v",
			opts.Name,
			opts.Host,
			opts.Database,
			"UTC",
		)
	} else {
		dsn = fmt.Sprintf(
			"%v:%v@tcp(%v)/%v?charset=utf8mb4&parseTime=True&loc=%v",
			opts.Name,
			opts.Password,
			opts.Host,
			opts.Database,
			"UTC",
		)
	}

	db, err := opts.OpenFunc(dsn)
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	// SetMaxOpenConns sets the maximum number of open connections to the database.
	sqlDB.SetMaxOpenConns(int(opts.MaxOpenConns))

	// SetMaxIdleConns sets the maximum number of connections in the idle connection pool.
	sqlDB.SetMaxIdleConns(int(opts.MaxIdleConns))

	// SetConnMaxLifetime sets the maximum amount of time a connection may be reused.
	sqlDB.SetConnMaxLifetime(time.Duration(opts.MaxConnLifetime))

	return db, nil
}
