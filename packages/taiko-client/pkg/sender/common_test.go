package sender

import (
	"math"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestSetConfigWithDefaultValues(t *testing.T) {
	cfg := setConfigWithDefaultValues(&Config{MaxRetrys: 1, MaxBlobFee: 1024})
	assert.Equal(t, uint64(50), cfg.GasGrowthRate)
	assert.Equal(t, uint64(1), cfg.MaxRetrys)
	assert.Equal(t, 5*time.Minute, cfg.MaxWaitingTime)
	assert.Equal(t, uint64(math.MaxUint64), cfg.MaxGasFee)
	assert.Equal(t, uint64(1024), cfg.MaxBlobFee)

	cfg = setConfigWithDefaultValues(nil)
	assert.Equal(t, cfg.GasGrowthRate, uint64(50))
}
