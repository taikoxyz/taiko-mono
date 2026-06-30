package relayer

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPaddedMessageGasLimit(t *testing.T) {
	assert.Equal(t, uint64(846990), PaddedMessageGasLimit(806657, false))
	assert.Equal(t, uint64(1446896), PaddedMessageGasLimit(1315360, true))
}
