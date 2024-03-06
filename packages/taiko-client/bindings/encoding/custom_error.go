package encoding

import (
	"errors"
	"strings"
)

// TryParsingCustomError tries to checks whether the given error is one of the
// custom errors defined the TaikoL1 / TaikoL2's ABI, if so, it will return
// the matched custom error, otherwise, it simply returns the original error.
func TryParsingCustomError(originalError error) error {
	errData := getErrorData(originalError)

	// if errData is unparsable and returns 0x, we should not match any errors.
	if errData == "0x" {
		return originalError
	}

	for _, customErrors := range customErrorMaps {
		for _, customError := range customErrors {
			if strings.HasPrefix(customError.ID.Hex(), errData) {
				return errors.New(customError.Name)
			}
		}
	}

	for _, hookCustomError := range AssignmentHookABI.Errors {
		if strings.HasPrefix(hookCustomError.ID.Hex(), errData) {
			return errors.New(hookCustomError.Name)
		}
	}

	return originalError
}

// getErrorData tries to parse the actual custom error data from the given error.
func getErrorData(err error) string {
	// Geth node custom errors, the actual struct of this error is go-ethereum's <rpc.jsonError Value>.
	gethJSONError, ok := err.(interface{ ErrorData() interface{} }) // nolint: errorlint
	if ok {
		if errData, ok := gethJSONError.ErrorData().(string); ok {
			return errData
		}
	}

	// Hardhat node custom errors, example:
	// "VM Exception while processing transaction: reverted with an unrecognized custom error (return data: 0xb6d363fd)"
	if strings.Contains(err.Error(), "reverted with an unrecognized custom error") {
		return err.Error()[len(err.Error())-11 : len(err.Error())-1]
	}

	return err.Error()
}
