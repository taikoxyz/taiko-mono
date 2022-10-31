package relayer

import (
	"testing"

	"gopkg.in/go-playground/assert.v1"
)

func Test_LogsBloomToBytes(t *testing.T) {

}

func Test_StringToABI_SignalProofABI(t *testing.T) {
	_, err := StringToABI(SignalProofAbiString)
	assert.Equal(t, nil, err)
}

func Test_StringToABI_StorageProofABI(t *testing.T) {
	_, err := StringToABI(StorageProofAbiString)
	assert.Equal(t, nil, err)
}

func Test_StringToABI_Invalid(t *testing.T) {
	_, err := StringToABI(`${]JD/`)
	assert.NotEqual(t, nil, err)
}
