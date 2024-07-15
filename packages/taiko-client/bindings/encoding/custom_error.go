package encoding

import (
	"context"
	"errors"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// BlockHashContractCallerAndChainReader represents a contract caller and chain reader.
type BlockHashContractCallerAndChainReader interface {
	bind.BlockHashContractCaller
	ethereum.TransactionReader
	ethereum.ChainReader
}

// TryParsingCustomErrorFromReceipt tries to parse the custom error from the given receipt.
func TryParsingCustomErrorFromReceipt(
	ctx context.Context,
	rpc BlockHashContractCallerAndChainReader,
	from common.Address,
	receipt *types.Receipt,
) error {
	// Get the block header of the receipt.
	header, err := rpc.HeaderByHash(ctx, receipt.BlockHash)
	if err != nil {
		return err
	}

	// Fetch the raw transaction.
	tx, _, err := rpc.TransactionByHash(ctx, receipt.TxHash)
	if err != nil {
		return err
	}

	// Call the contract at the block hash.
	_, err = rpc.CallContractAtHash(ctx, ethereum.CallMsg{
		From:          from,
		To:            tx.To(),
		Gas:           tx.Gas(),
		GasFeeCap:     tx.GasFeeCap(),
		GasTipCap:     tx.GasTipCap(),
		Value:         tx.Value(),
		Data:          tx.Data(),
		AccessList:    tx.AccessList(),
		BlobGasFeeCap: tx.BlobGasFeeCap(),
		BlobHashes:    tx.BlobHashes(),
	}, header.ParentHash)

	return TryParsingCustomError(err)
}

// TryParsingCustomError tries to checks whether the given error is one of the
// custom errors defined the protocol ABIs, if so, it will return
// the matched custom error, otherwise, it simply returns the original error.
func TryParsingCustomError(originalError error) error {
	if originalError == nil {
		return nil
	}

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
	// Anvil node custom errors, example:
	// "execution reverted: custom error 712eb087:"
	if strings.Contains(err.Error(), "custom error") {
		return "0x" + err.Error()[len(err.Error())-9:len(err.Error())-1]
	}

	return err.Error()
}
