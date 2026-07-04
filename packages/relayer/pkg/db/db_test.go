package db

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

func Test_DB(t *testing.T) {
	d := New(&gorm.DB{})

	assert.Equal(t, &gorm.DB{}, d.GormDB())
}

func TestConnMaxLifetimeFromSeconds(t *testing.T) {
	assert.Equal(t, 30*time.Second, ConnMaxLifetimeFromSeconds(30))
}
