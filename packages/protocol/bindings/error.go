package bindings

import (
	"encoding/json"
	"errors"
	"fmt"

	"github.com/ethereum/go-ethereum/crypto"
)

// Taken from: https://github.com/ethereum/go-ethereum/blob/master/rpc/json.go
type JsonRPCError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// Error implements the Go error interface.
func (err *JsonRPCError) Error() string {
	if err.Message == "" {
		return fmt.Sprintf("json-rpc error %d", err.Code)
	}
	return err.Message
}

// GetRevertReasonHash returns a solidity contract call revert reason hash.
func GetRevertReasonHash(err error) (string, error) {
	bytes, err := json.Marshal(errors.Unwrap(err))
	if err != nil {
		return "", err
	}
	rpcError := new(JsonRPCError)
	if err = json.Unmarshal(bytes, rpcError); err != nil {
		return "", err
	}
	reasonHash, ok := rpcError.Data.(string)
	if !ok {
		return "", fmt.Errorf("invalid revert reason, %T", rpcError.Data)
	}
	return reasonHash, nil
}

// CheckExpectRevertReason checks if the revert reason in solidity contracts matches the expectation.
func CheckExpectRevertReason(expect string, revertErr error) (bool, error) {
	reason, err := GetRevertReasonHash(revertErr)
	if err != nil {
		return false, err
	}
	return fmt.Sprintf("%#x", crypto.Keccak256([]byte(expect)))[:10] == reason, nil
}
