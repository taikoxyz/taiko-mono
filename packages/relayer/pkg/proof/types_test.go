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

func Test_Slice(t *testing.T) {
	b := [][]byte{
		[]byte("0x123"),
	}

	e := []uint8([]byte{0x5b, 0x22, 0x30, 0x78, 0x33, 0x30, 0x37, 0x38, 0x33, 0x31, 0x33, 0x32, 0x33, 0x33, 0x22, 0x5d})

	s := Slice(b)

	marshalled, err := s.MarshalJSON()
	assert.Nil(t, err)
	assert.Equal(t, marshalled, e)

	new := Slice{}
	err = new.UnmarshalJSON(e)
	assert.Nil(t, err)
	assert.Equal(t, s, s)
}
