package proof

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_Bytes(t *testing.T) {
	b := Bytes("0x1234")
	e := []byte{0x30, 0x78, 0x33, 0x30, 0x37, 0x38, 0x33, 0x31, 0x33, 0x32, 0x33, 0x33, 0x33, 0x34}
	marshalled, err := b.MarshalText()
	assert.Nil(t, err)
	assert.Equal(t, e, marshalled)
	err = b.UnmarshalText([]byte("0x4321"))
	assert.Nil(t, err)
	assert.Equal(t, Bytes([]byte{0x43, 0x21}), b)
}

func Test_Bytes_UnmarshalText_invalidHexInput(t *testing.T) {
	b := Bytes("0x1234")
	err := b.UnmarshalText([]byte(">>"))
	assert.EqualError(t, err, "invalid hex input")
}
