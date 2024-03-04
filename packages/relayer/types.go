package relayer

import (
	"context"
	"fmt"
	"math/big"
	"strconv"
	"time"

	"log/slog"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
)

var (
	ZeroHash    = common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000")
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

// IsInSlice determines whether v is in slice s
func IsInSlice[T comparable](v T, s []T) bool {
	for _, e := range s {
		if v == e {
			return true
		}
	}

	return false
}

type confirmer interface {
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
}

// WaitReceipt keeps waiting until the given transaction has an execution
// receipt to know whether it was reverted or not.
func WaitReceipt(ctx context.Context, confirmer confirmer, txHash common.Hash) (*types.Receipt, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	slog.Info("waiting for transaction receipt", "txHash", txHash.Hex())

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			receipt, err := confirmer.TransactionReceipt(ctx, txHash)
			if err != nil {
				continue
			}

			if receipt.Status != types.ReceiptStatusSuccessful {
				return nil, fmt.Errorf("transaction reverted, hash: %s", txHash)
			}

			slog.Info("transaction receipt found", "txHash", txHash.Hex())

			return receipt, nil
		}
	}
}

// WaitConfirmations won't return before N blocks confirmations have been seen
// on destination chain, or context is cancelled.
func WaitConfirmations(ctx context.Context, confirmer confirmer, confirmations uint64, txHash common.Hash) error {
	slog.Info("beginning waiting for confirmations", "txHash", txHash.Hex())

	ticker := time.NewTicker(10 * time.Second)

	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			receipt, err := confirmer.TransactionReceipt(ctx, txHash)
			if err != nil {
				if err == ethereum.NotFound {
					continue
				}

				slog.Error("encountered error getting receipt", "txHash", txHash.Hex(), "error", err)

				return err
			}

			latest, err := confirmer.BlockNumber(ctx)
			if err != nil {
				return err
			}

			want := receipt.BlockNumber.Uint64() + confirmations
			slog.Info(
				"waiting for confirmations",
				"txHash", txHash.Hex(),
				"confirmations", confirmations,
				"blockNumWillbeConfirmed", want,
				"latestBlockNum", latest,
			)

			if latest < receipt.BlockNumber.Uint64()+confirmations {
				continue
			}

			slog.Info("done waiting for confirmations", "txHash", txHash.Hex(), "confirmations", confirmations)

			return nil
		}
	}
}

// splitByteArray splits a byte array into chunks of chunkSize.
// It returns a slice of byte slices.
func splitByteArray(data []byte, chunkSize int) [][]byte {
	var chunks [][]byte

	for i := 0; i < len(data); i += chunkSize {
		end := i + chunkSize
		// Ensure we don't go past the end of the slice
		if end > len(data) {
			end = len(data)
		}

		chunks = append(chunks, data[i:end])
	}

	return chunks
}

func decodeDataAsERC20(decodedData []byte) (CanonicalToken, *big.Int, error) {
	var token CanonicalERC20

	chunks := splitByteArray(decodedData, 32)
	offset, err := strconv.ParseInt(common.Bytes2Hex((chunks[0])), 16, 64)

	if err != nil {
		return token, big.NewInt(0), err
	}

	canonicalTokenData := decodedData[offset:]

	types := []string{"uint64", "address", "uint8", "string", "string"}
	values, err := decodeABI(types, canonicalTokenData)

	if err != nil && len(values) != 5 {
		return token, big.NewInt(0), err
	}

	token.ChainId = values[0].(uint64)
	token.Addr = values[1].(common.Address)
	token.Decimals = uint8(values[2].(uint8))
	token.Symbol = values[3].(string)
	token.Name = values[4].(string)

	amount, err := strconv.ParseInt(common.Bytes2Hex((chunks[3])), 16, 64)
	if err != nil {
		return token, big.NewInt(0), err
	}

	return token, big.NewInt(amount), nil
}

func decodeDataAsNFT(decodedData []byte) (EventType, CanonicalToken, *big.Int, error) {
	var token CanonicalNFT

	chunks := splitByteArray(decodedData, 32)

	offset, err := strconv.ParseInt(common.Bytes2Hex((chunks[0])), 16, 64)

	if err != nil || offset%32 != 0 {
		return EventTypeSendETH, token, big.NewInt(0), err
	}

	canonicalTokenData := decodedData[offset:]

	types := []string{"uint64", "address", "string", "string"}
	values, err := decodeABI(types, canonicalTokenData)

	if err != nil && len(values) != 4 {
		return EventTypeSendETH, token, big.NewInt(0), err
	}

	token.ChainId = values[0].(uint64)
	token.Addr = values[1].(common.Address)
	token.Symbol = values[2].(string)
	token.Name = values[3].(string)

	if offset == 128 {
		amount := big.NewInt(1)

		return EventTypeSendERC721, token, amount, nil
	} else if offset == 160 {
		offset, err := strconv.ParseInt(common.Bytes2Hex((chunks[4])), 16, 64)
		if err != nil || offset%32 != 0 {
			return EventTypeSendETH, token, big.NewInt(0), err
		}

		indexOffset := int64(offset / 32)

		length, err := strconv.ParseInt(common.Bytes2Hex((chunks[indexOffset])), 16, 64)

		if err != nil {
			return EventTypeSendETH, token, big.NewInt(0), err
		}

		amount := big.NewInt(0)

		for i := int64(0); i < length; i++ {
			amountsData := decodedData[(indexOffset+i+1)*32 : (indexOffset+i+2)*32]
			types := []string{"uint256"}
			values, err = decodeABI(types, amountsData)

			if err != nil && len(values) != 1 {
				return EventTypeSendETH, token, big.NewInt(0), err
			}

			amount = amount.Add(amount, values[0].(*big.Int))
		}

		return EventTypeSendERC1155, token, amount, nil
	}

	return EventTypeSendETH, token, big.NewInt(0), nil
}

func decodeABI(types []string, data []byte) ([]interface{}, error) {
	arguments := make(abi.Arguments, len(types))
	for i, t := range types {
		arguments[i].Type, _ = abi.NewType(t, "", nil)
	}

	values, err := arguments.UnpackValues(data)
	if err != nil {
		return nil, err
	}

	return values, nil
}

// DecodeMessageData tries to tell if it's an ETH, ERC20, ERC721, or ERC1155 bridge,
// which lets the processor look up whether the contract has already been deployed or not,
// to help better estimate gas needed for processing the message.
func DecodeMessageData(eventData []byte, value *big.Int) (EventType, CanonicalToken, *big.Int, error) {
	// Default eventType is ETH
	eventType := EventTypeSendETH

	var canonicalToken CanonicalToken

	var amount *big.Int = value

	onMessageInvocationFunctionSig := "7f07c947"

	// Check if eventData is valid
	if eventData != nil &&
		common.BytesToHash(eventData) != ZeroHash &&
		len(eventData) > 3 &&
		common.Bytes2Hex(eventData[:4]) == onMessageInvocationFunctionSig {
		// Try to decode data as ERC20
		canonicalToken, amount, err := decodeDataAsERC20(eventData[4:])

		if err == nil {
			return EventTypeSendERC20, canonicalToken, amount, nil
		}

		// Try to decode data as NFT
		eventType, canonicalToken, amount, err = decodeDataAsNFT(eventData[4:])

		if err == nil {
			return eventType, canonicalToken, amount, nil
		}
	}

	return eventType, canonicalToken, amount, nil
}

type CanonicalToken interface {
	ChainID() uint64
	Address() common.Address
	ContractName() string
	TokenDecimals() uint8
	ContractSymbol() string
}

type CanonicalERC20 struct {
	// nolint
	ChainId  uint64         `json:"chainId"`
	Addr     common.Address `json:"addr"`
	Decimals uint8          `json:"decimals"`
	Symbol   string         `json:"symbol"`
	Name     string         `json:"name"`
}

func (c CanonicalERC20) ChainID() uint64 {
	return c.ChainId
}

func (c CanonicalERC20) Address() common.Address {
	return c.Addr
}

func (c CanonicalERC20) ContractName() string {
	return c.Name
}

func (c CanonicalERC20) ContractSymbol() string {
	return c.Symbol
}

func (c CanonicalERC20) TokenDecimals() uint8 {
	return c.Decimals
}

type CanonicalNFT struct {
	// nolint
	ChainId uint64         `json:"chainId"`
	Addr    common.Address `json:"addr"`
	Symbol  string         `json:"symbol"`
	Name    string         `json:"name"`
}

func (c CanonicalNFT) ChainID() uint64 {
	return c.ChainId
}

func (c CanonicalNFT) Address() common.Address {
	return c.Addr
}

func (c CanonicalNFT) ContractName() string {
	return c.Name
}

func (c CanonicalNFT) TokenDecimals() uint8 {
	return 0
}

func (c CanonicalNFT) ContractSymbol() string {
	return c.Symbol
}

// DecodeRevertReason decodes a hex-encoded revert reason from an Ethereum transaction.
func DecodeRevertReason(hexStr string) (string, error) {
	// Decode the hex string to bytes
	data, err := hexutil.Decode(hexStr)
	if err != nil {
		return "", err
	}

	// Ensure the data is long enough to contain a valid revert reason
	if len(data) < 68 {
		return "", fmt.Errorf("data too short to contain a valid revert reason")
	}

	// The revert reason is encoded in the data returned by a failed transaction call
	// It starts with the error signature 0x08c379a0 (method ID), followed by the offset
	// of the string data, the length of the string, and finally the string itself.

	// Skip the first 4 bytes (method ID) and the next 32 bytes (offset)
	// Then read the length of the string (next 32 bytes)
	strLen := new(big.Int).SetBytes(data[36:68]).Uint64()

	// Ensure the data contains the full revert string
	if uint64(len(data)) < 68+strLen {
		return "", fmt.Errorf("data too short to contain the full revert reason")
	}

	// Extract the revert reason string
	revertReason := string(data[68 : 68+strLen])

	return revertReason, nil
}
