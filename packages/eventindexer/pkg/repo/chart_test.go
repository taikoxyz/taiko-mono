package repo

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func Test_NewChartRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      eventindexer.DB
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
			eventindexer.ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewChartRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func Test_GetDB(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	chartRepo, err := NewChartRepository(db)
	assert.Equal(t, nil, err)
	assert.NotNil(t, chartRepo.getDB())
}

func Test_Integration_FindChart(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	chartRepo, err := NewChartRepository(db)
	assert.Equal(t, nil, err)

	chart, err := chartRepo.Find(
		context.Background(),
		"test",
		"2023-09-08",
		"2023-09-09",
		"0x01",
		"",
	)
	assert.Equal(t, nil, err)
	assert.Equal(t, 0, len(chart.Chart))
}
