package relayer

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"
	"unicode/utf8"

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

type confirmer interface {
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
}

// WaitReceipt keeps waiting until the given transaction has an execution
// receipt to know whether it was reverted or not.
func WaitReceipt(ctx context.Context, confirmer confirmer, txHash common.Hash) (*types.Receipt, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

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

			return receipt, nil
		}
	}
}

var (
	errStillWaiting = errors.New("still waiting")
)

// WaitConfirmations won't return before N blocks confirmations have been seen
// on destination chain, or context is cancelled. It checks once before polling,
// so a transaction that already has its confirmations returns without waiting
// for a tick.
//
// That first check still goes through the client, so with a real one an already
// cancelled context fails the receipt lookup and this returns that error rather
// than the receipt. Only a client that ignores its context, such as the test
// mock, can report success over a cancelled context.
func WaitConfirmations(ctx context.Context, confirmer confirmer, confirmations uint64, txHash common.Hash) error {
	checkConfs := func() error {
		receipt, err := confirmer.TransactionReceipt(ctx, txHash)
		if err != nil {
			return err
		}

		latest, err := confirmer.BlockNumber(ctx)
		if err != nil {
			return err
		}

		want := receipt.BlockNumber.Uint64() + confirmations

		if latest < want {
			slog.Info("waiting for confirmations", "latestBlockNum", latest, "wantBlockNum", want)

			return errStillWaiting
		}

		return nil
	}

	// the transaction may already have the confirmations we need, in which case
	// we are done without ever waiting on the ticker below.
	err := checkConfs()
	if err == nil {
		return nil
	}

	if err != ethereum.NotFound && err != errStillWaiting {
		slog.Error("encountered error getting receipt", "txHash", txHash.Hex(), "error", err)

		return err
	}

	ticker := time.NewTicker(10 * time.Second)

	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if err := checkConfs(); err != nil {
				if err == ethereum.NotFound || err == errStillWaiting {
					continue
				}

				slog.Error("encountered error getting receipt", "txHash", txHash.Hex(), "error", err)

				return err
			}

			return nil
		}
	}
}

// splitByteArray splits a byte array into chunks of chunkSize.
// It returns a slice of byte slices.
func splitByteArray(data []byte, chunkSize int) [][]byte {
	var chunks [][]byte

	for i := 0; i < len(data); i += chunkSize {
		end := min(i+chunkSize, len(data))
		chunks = append(chunks, data[i:end])
	}

	return chunks
}

func decodeDataAsERC20(decodedData []byte) (CanonicalToken, *big.Int, error) {
	var token CanonicalERC20

	canonicalTokenDataStartingindex := int64(2)
	chunks := splitByteArray(decodedData, 32)

	if len(chunks) < 4 {
		return token, big.NewInt(0), errors.New("data too short")
	}

	offset, ok := new(big.Int).SetString(common.Bytes2Hex((chunks[canonicalTokenDataStartingindex])), 16)

	if !ok {
		return token, big.NewInt(0), errors.New("data for BigInt is invalid")
	}

	// Calculate the starting index for canonicalTokenData
	startIndex := offset.Int64() + canonicalTokenDataStartingindex*32

	// Boundary check
	if startIndex >= int64(len(decodedData)) || startIndex < 0 {
		slog.Warn("startIndex greater than decodedData length",
			"startIndex", startIndex,
			"lenDecodedData", int64(len(decodedData)),
		)

		return token, big.NewInt(0), errors.New("calculated index is out of bounds")
	}

	canonicalTokenData := decodedData[startIndex:]

	types := []string{"uint64", "address", "uint8", "string", "string"}
	values, err := decodeABI(types, canonicalTokenData)

	if err != nil && len(values) != 5 {
		return token, big.NewInt(0), err
	}

	// Type assertions and validations
	chainId, ok := values[0].(uint64)
	if !ok {
		return token, big.NewInt(0), errors.New("invalid chainId type")
	}

	addr, ok := values[1].(common.Address)
	if !ok {
		return token, big.NewInt(0), errors.New("invalid address type")
	}

	decimals, ok := values[2].(uint8)
	if !ok {
		return token, big.NewInt(0), errors.New("invalid decimals type")
	}

	symbol, ok := values[3].(string)
	if !ok || !utf8.ValidString(symbol) {
		return token, big.NewInt(0), errors.New("invalid symbol string")
	}

	name, ok := values[4].(string)
	if !ok || !utf8.ValidString(name) {
		return token, big.NewInt(0), errors.New("invalid name string")
	}

	token.ChainId = chainId
	token.Addr = addr
	token.Decimals = decimals
	token.Symbol = symbol
	token.Name = name

	amount, ok := new(big.Int).SetString(common.Bytes2Hex((chunks[canonicalTokenDataStartingindex+3])), 16)
	if !ok {
		return token, big.NewInt(0), errors.New("data for BigInt is invalid")
	}

	return token, amount, nil
}

func decodeDataAsNFT(decodedData []byte) (EventType, CanonicalToken, *big.Int, error) {
	var token CanonicalNFT

	canonicalTokenDataStartingindex := int64(2)
	chunks := splitByteArray(decodedData, 32)

	offset, ok := new(big.Int).SetString(common.Bytes2Hex((chunks[canonicalTokenDataStartingindex])), 16)

	if !ok || offset.Int64()%32 != 0 {
		return EventTypeSendETH, token, big.NewInt(0), errors.New("data for BigInt is invalid")
	}

	// Calculate the starting index for canonicalTokenData
	startIndex := offset.Int64() + canonicalTokenDataStartingindex*32

	// Boundary check
	if startIndex >= int64(len(decodedData)) || startIndex < 0 {
		slog.Warn("startIndex greater than decodedData length",
			"startIndex", startIndex,
			"lenDecodedData", int64(len(decodedData)),
		)

		return EventTypeSendETH, token, big.NewInt(0), errors.New("calculated index is out of bounds")
	}

	canonicalTokenData := decodedData[startIndex:]

	types := []string{"uint64", "address", "string", "string"}
	values, err := decodeABI(types, canonicalTokenData)

	if err != nil && len(values) != 4 {
		return EventTypeSendETH, token, big.NewInt(0), err
	}

	// Type assertions and validations
	chainId, ok := values[0].(uint64)
	if !ok {
		return EventTypeSendETH, token, big.NewInt(0), errors.New("invalid chainId type")
	}

	addr, ok := values[1].(common.Address)
	if !ok {
		return EventTypeSendETH, token, big.NewInt(0), errors.New("invalid address type")
	}

	symbol, ok := values[2].(string)
	if !ok || !utf8.ValidString(symbol) {
		return EventTypeSendETH, token, big.NewInt(0), errors.New("invalid symbol string")
	}

	name, ok := values[3].(string)
	if !ok || !utf8.ValidString(name) {
		return EventTypeSendETH, token, big.NewInt(0), errors.New("invalid name string")
	}

	token.ChainId = chainId
	token.Addr = addr
	token.Symbol = symbol
	token.Name = name

	if offset.Int64() == sharedCanonicalTokenOffset {
		amount := big.NewInt(1)

		return EventTypeSendERC721, token, amount, nil
	} else if offset.Int64() == erc1155CanonicalTokenOffset {
		offset, ok := new(big.Int).SetString(common.Bytes2Hex((chunks[canonicalTokenDataStartingindex+4])), 16)
		if !ok || offset.Int64()%32 != 0 {
			return EventTypeSendETH, token, big.NewInt(0), errors.New("data for BigInt is invalid")
		}

		indexOffset := canonicalTokenDataStartingindex + int64(offset.Int64()/32)

		length, ok := new(big.Int).SetString(common.Bytes2Hex((chunks[indexOffset])), 16)
		if !ok {
			return EventTypeSendETH, token, big.NewInt(0), errors.New("data for BigInt is invalid")
		}

		amount := big.NewInt(0)

		for i := int64(0); i < length.Int64(); i++ {
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

const (
	// Index of the 32-byte word holding the head offset of the canonical token, once an
	// onMessageInvocation payload is split into words: [bytes head][bytes length][token head].
	canonicalTokenOffsetWordIndex = int64(2)
	// That head offset is 128 when the payload has four head words (ERC20Vault, ERC721Vault)
	// and 160 when it has five (ERC1155Vault).
	sharedCanonicalTokenOffset  = int64(128)
	erc1155CanonicalTokenOffset = int64(160)
)

// carriesCanonicalNFT reports whether an onMessageInvocation payload was built by one of the
// NFT vaults rather than by the ERC20 vault, reading the ABI head layout instead of trial
// decoding. The three vaults encode:
//
//	ERC20Vault:   abi.encode(CanonicalERC20, address, address, uint256)             -> 4 head words
//	ERC721Vault:  abi.encode(CanonicalNFT,   address, address, uint256[])           -> 4 head words
//	ERC1155Vault: abi.encode(CanonicalNFT,   address, address, uint256[], uint256[]) -> 5 head words
//
// so the head offset of the canonical token is 160 only for an ERC1155 send. At 128 the two
// layouts are told apart by the third word of the canonical tuple itself: CanonicalNFT has four
// head words, making its third word the head of `symbol`, which is always 128, whereas
// CanonicalERC20 carries `decimals` in that slot. An ERC20 would need 128 decimals to collide.
func carriesCanonicalNFT(decodedData []byte) bool {
	chunks := splitByteArray(decodedData, 32)

	if int64(len(chunks)) <= canonicalTokenOffsetWordIndex {
		return false
	}

	offset, ok := new(big.Int).SetString(common.Bytes2Hex(chunks[canonicalTokenOffsetWordIndex]), 16)
	if !ok {
		return false
	}

	switch offset.Int64() {
	case erc1155CanonicalTokenOffset:
		return true
	case sharedCanonicalTokenOffset:
		// Third word of the canonical tuple, which starts at byte offset+64.
		index := offset.Int64()/32 + canonicalTokenOffsetWordIndex + 2
		if int64(len(chunks)) <= index {
			return false
		}

		word, ok := new(big.Int).SetString(common.Bytes2Hex(chunks[index]), 16)

		return ok && word.Int64() == sharedCanonicalTokenOffset
	default:
		return false
	}
}

// DecodeMessageData tries to tell if it's an ETH, ERC20, ERC721, or ERC1155 bridge,
// which lets the processor look up whether the contract has already been deployed or not,
// to help better estimate gas needed for processing the message.
func DecodeMessageData(eventData []byte, value *big.Int) (EventType, CanonicalToken, *big.Int, error) {
	// Default eventType is ETH
	eventType := EventTypeSendETH

	var canonicalToken CanonicalToken

	var amount = value

	onMessageInvocationFunctionSig := "7f07c947"

	// Check if eventData is valid
	if len(eventData) > 3 &&
		common.Bytes2Hex(eventData[:4]) == onMessageInvocationFunctionSig {
		payload := eventData[4:]

		asERC20 := func() (EventType, CanonicalToken, *big.Int, error) {
			token, amount, err := decodeDataAsERC20(payload)

			return EventTypeSendERC20, token, amount, err
		}

		asNFT := func() (EventType, CanonicalToken, *big.Int, error) {
			return decodeDataAsNFT(payload)
		}

		// The decoders are tried in the order the head layout suggests rather than ERC20 first
		// unconditionally, because decodeDataAsERC20 reads whatever sits at the ERC20 offsets: an
		// NFT payload whose canonical symbol and name are both empty decodes without erroring into
		// garbage, taking the symbol head (128) for `decimals` and the tokenIds array offset for
		// the amount. The other decoder is still tried second, so a payload the layout check
		// misreads is no worse off than before.
		attempts := []func() (EventType, CanonicalToken, *big.Int, error){asERC20, asNFT}
		if carriesCanonicalNFT(payload) {
			attempts = []func() (EventType, CanonicalToken, *big.Int, error){asNFT, asERC20}
		}

		for _, attempt := range attempts {
			decodedType, decodedToken, decodedAmount, err := attempt()
			if err == nil {
				return decodedType, decodedToken, decodedAmount, nil
			}
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
		return "", errors.New("data too short to contain a valid revert reason")
	}

	// The revert reason is encoded in the data returned by a failed transaction call
	// It starts with the error signature 0x08c379a0 (method ID), followed by the offset
	// of the string data, the length of the string, and finally the string itself.

	// Skip the first 4 bytes (method ID) and the next 32 bytes (offset)
	// Then read the length of the string (next 32 bytes)
	strLen := new(big.Int).SetBytes(data[36:68]).Uint64()

	// Ensure the data contains the full revert string
	if uint64(len(data)) < 68+strLen {
		return "", errors.New("data too short to contain the full revert reason")
	}

	// Extract the revert reason string
	revertReason := string(data[68 : 68+strLen])

	return revertReason, nil
}
