package db

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

func Test_DB(t *testing.T) {
	d := New(&gorm.DB{})

	assert.Equal(t, &gorm.DB{}, d.GormDB())
}
