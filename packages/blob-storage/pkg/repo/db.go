package repo

import (
	"database/sql"

	"github.com/cyberhorsey/errors"
	"gorm.io/gorm"
)

var (
	ErrNoDB = errors.Validation.NewWithKeyAndDetail("ERR_NO_DB", "no db")
)

type DB interface {
	DB() (*sql.DB, error)
	GormDB() *gorm.DB
}
