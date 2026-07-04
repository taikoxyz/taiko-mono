package watchdog

import (
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_Name(t *testing.T) {
	w := Watchdog{}

	assert.Equal(t, "watchdog", w.Name())
}

func Test_queueName(t *testing.T) {
	w := Watchdog{
		srcChainId:  big.NewInt(1),
		destChainId: big.NewInt(2),
	}

	assert.Equal(t, "1-2-MessageProcessed-queue", w.queueName())
}
