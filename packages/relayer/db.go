package relayer

import "github.com/cyberhorsey/errors"

var (
	ErrNoDB = errors.Validation.NewWithKeyAndDetail("ERR_NO_DB", "DB is required")
)

type DBConnectionOpts struct {
	Name     string
	Password string
	Host     string
	Database string
}
