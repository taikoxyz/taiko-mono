package encoding

import (
	"errors"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

type testJSONError struct{}

func (e *testJSONError) Error() string { return common.Bytes2Hex(randomBytes(10)) }

func (e *testJSONError) ErrorData() interface{} { return "0x8a1c400f" }

type emptyTestJSONError struct{}

func (e *emptyTestJSONError) Error() string { return "execution reverted" }

func (e *emptyTestJSONError) ErrorData() interface{} { return "0x" }

func TestTryParsingCustomError(t *testing.T) {
	randomErr := common.Bytes2Hex(randomBytes(10))
	require.Equal(t, randomErr, TryParsingCustomError(errors.New(randomErr)).Error())

	err := TryParsingCustomError(errors.New(
		// L1_INVALID_BLOCK_ID
		"VM Exception while processing transaction: reverted with an unrecognized custom error (return data: 0x8a1c400f)",
	))

	require.True(t, strings.HasPrefix(err.Error(), "L1_INVALID_BLOCK_ID"))

	err = TryParsingCustomError(&testJSONError{})

	require.True(t, strings.HasPrefix(err.Error(), "L1_INVALID_BLOCK_ID"))

	err = TryParsingCustomError(&emptyTestJSONError{})

	require.Equal(t, err.Error(), "execution reverted")
}
