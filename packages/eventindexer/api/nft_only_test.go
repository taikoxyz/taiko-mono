package api

import (
	"context"
	"database/sql"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"gorm.io/gorm"
)

type queryDB struct{ closed bool }

func (d *queryDB) DB() (*sql.DB, error) { return nil, nil }
func (d *queryDB) GormDB() *gorm.DB     { return nil }
func (d *queryDB) Close() error         { d.closed = true; return nil }

func TestQueryAPIInitializesWithoutRPC(t *testing.T) {
	database := &queryDB{}
	api := &API{}
	require.NoError(t, InitFromConfig(context.Background(), api, &Config{OpenDBFunc: func() (db.DB, error) { return database, nil }}))
	api.Close(context.Background())
	require.True(t, database.closed)
}

func TestAPIFlagsDoNotRequireRPC(t *testing.T) {
	app := setupApp()
	require.NoError(t, app.Run([]string{"api", "--db.username", "user", "--db.password", "pass", "--db.host", "host", "--db.name", "name"}))
}
