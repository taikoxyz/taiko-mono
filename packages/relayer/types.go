package relayer

import (
	"bytes"
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

// The vault payloads, exactly as the vaults build them:
//
//	ERC20Vault:   abi.encode(CanonicalERC20, address from, address to, uint256 amount)
//	ERC721Vault:  abi.encode(CanonicalNFT,   address from, address to, uint256[] tokenIds)
//	ERC1155Vault: abi.encode(CanonicalNFT,   address from, address to, uint256[] tokenIds, uint256[] amounts)
//
// plus the shape the solver-era ERC20Vault used between #18616 (Dec 2024) and #19959 (Aug 2025):
//
//	ERC20Vault:   abi.encode(CanonicalERC20, address from, address to, uint256 amount,
//	                         uint256 solverFee, bytes32 solverCondition)
//
// Held as real ABI schemas so the payload is decoded rather than read at hand-computed offsets.
var (
	erc20PayloadArgs = mustArguments(
		canonicalERC20Tuple(),
		abi.ArgumentMarshaling{Name: "from", Type: "address"},
		abi.ArgumentMarshaling{Name: "to", Type: "address"},
		abi.ArgumentMarshaling{Name: "amount", Type: "uint256"},
	)

	// No mainnet or Hoodi vault implementation was cut from the solver window, but Hekla's was, and
	// those sends are still ERC20 transfers: `amount` is the recipient's, as the vault's TokenSent
	// event reports it, and the fee rides separately. Six head words, so no other schema here can
	// reproduce this payload and vice versa.
	erc20SolverPayloadArgs = mustArguments(
		canonicalERC20Tuple(),
		abi.ArgumentMarshaling{Name: "from", Type: "address"},
		abi.ArgumentMarshaling{Name: "to", Type: "address"},
		abi.ArgumentMarshaling{Name: "amount", Type: "uint256"},
		abi.ArgumentMarshaling{Name: "solverFee", Type: "uint256"},
		abi.ArgumentMarshaling{Name: "solverCondition", Type: "bytes32"},
	)

	erc721PayloadArgs = mustArguments(
		canonicalNFTTuple(),
		abi.ArgumentMarshaling{Name: "from", Type: "address"},
		abi.ArgumentMarshaling{Name: "to", Type: "address"},
		abi.ArgumentMarshaling{Name: "tokenIds", Type: "uint256[]"},
	)

	erc1155PayloadArgs = mustArguments(
		canonicalNFTTuple(),
		abi.ArgumentMarshaling{Name: "from", Type: "address"},
		abi.ArgumentMarshaling{Name: "to", Type: "address"},
		abi.ArgumentMarshaling{Name: "tokenIds", Type: "uint256[]"},
		abi.ArgumentMarshaling{Name: "amounts", Type: "uint256[]"},
	)

	// onMessageInvocation takes a single `bytes`, so the payload is wrapped once more.
	invocationArgs = mustArguments(abi.ArgumentMarshaling{Name: "data", Type: "bytes"})
)

func canonicalERC20Tuple() abi.ArgumentMarshaling {
	return tupleType("ctoken",
		abi.ArgumentMarshaling{Name: "chainId", Type: "uint64"},
		abi.ArgumentMarshaling{Name: "addr", Type: "address"},
		abi.ArgumentMarshaling{Name: "decimals", Type: "uint8"},
		abi.ArgumentMarshaling{Name: "symbol", Type: "string"},
		abi.ArgumentMarshaling{Name: "name", Type: "string"},
	)
}

func canonicalNFTTuple() abi.ArgumentMarshaling {
	return tupleType("ctoken",
		abi.ArgumentMarshaling{Name: "chainId", Type: "uint64"},
		abi.ArgumentMarshaling{Name: "addr", Type: "address"},
		abi.ArgumentMarshaling{Name: "symbol", Type: "string"},
		abi.ArgumentMarshaling{Name: "name", Type: "string"},
	)
}

func tupleType(name string, components ...abi.ArgumentMarshaling) abi.ArgumentMarshaling {
	return abi.ArgumentMarshaling{Name: name, Type: "tuple", Components: components}
}

// mustArguments builds a fixed schema known at compile time, so a failure here is a programming
// error rather than anything the chain can cause.
func mustArguments(marshalings ...abi.ArgumentMarshaling) abi.Arguments {
	arguments := make(abi.Arguments, len(marshalings))

	for i, marshaling := range marshalings {
		argType, err := abi.NewType(marshaling.Type, marshaling.InternalType, marshaling.Components)
		if err != nil {
			panic(fmt.Sprintf("relayer: bad ABI schema for %q: %v", marshaling.Name, err))
		}

		arguments[i] = abi.Argument{Name: marshaling.Name, Type: argType}
	}

	return arguments
}

// decodeExactly unpacks data against args and requires it to re-encode to exactly the same bytes.
//
// The round trip is what makes the answer definitive. Unpacking alone is not: solidity's
// abi.encode output for one vault is frequently *readable* as another vault's shape, which is how
// an ERC1155 send with an empty canonical symbol and name used to be indexed as an ERC20 - the
// symbol's head offset was taken for `decimals` and the tokenIds array offset for the amount. The
// encoding is canonical, so bytes that survive a decode/re-encode under one schema were produced
// by that schema; anything reachable only by misreading the offsets fails to reproduce them. It
// also rejects trailing bytes, which Unpack alone ignores.
func decodeExactly(args abi.Arguments, data []byte) ([]interface{}, bool) {
	values, err := args.Unpack(data)
	if err != nil {
		return nil, false
	}

	reencoded, err := args.Pack(values...)
	if err != nil || !bytes.Equal(reencoded, data) {
		return nil, false
	}

	return values, true
}

// sumAmounts adds an ERC1155 send's amounts. The values come from a decoded uint256[], so they are
// non-negative and already bounded by the payload length.
func sumAmounts(amounts []*big.Int) *big.Int {
	total := big.NewInt(0)
	for _, amount := range amounts {
		total = total.Add(total, amount)
	}

	return total
}

// DecodeMessageData tries to tell if it's an ETH, ERC20, ERC721, or ERC1155 bridge,
// which lets the processor look up whether the contract has already been deployed or not,
// to help better estimate gas needed for processing the message.
//
// Anyone can call Bridge.sendMessage with arbitrary `data`, so every step here treats the payload
// as hostile: it is decoded through the ABI package, which bounds-checks offsets and lengths and
// reports a malformed payload as an error, and an unrecognised payload falls back to ETH rather
// than failing the caller.
func DecodeMessageData(eventData []byte, value *big.Int) (EventType, CanonicalToken, *big.Int, error) {
	// Default eventType is ETH
	eventType := EventTypeSendETH

	var canonicalToken CanonicalToken

	var amount = value

	onMessageInvocationFunctionSig := "7f07c947"

	// Check if eventData is valid
	if len(eventData) <= 3 || common.Bytes2Hex(eventData[:4]) != onMessageInvocationFunctionSig {
		return eventType, canonicalToken, amount, nil
	}

	invocation, ok := decodeExactly(invocationArgs, eventData[4:])
	if !ok {
		return eventType, canonicalToken, amount, nil
	}

	payload, ok := invocation[0].([]byte)
	if !ok {
		return eventType, canonicalToken, amount, nil
	}

	// Each schema is exact, so the order only settles a payload that is canonical under more than
	// one of them - which the differing head-word counts make unreachable for the real vaults.
	// Both ERC20 shapes carry the amount in the fourth word.
	for _, args := range []abi.Arguments{erc20PayloadArgs, erc20SolverPayloadArgs} {
		values, ok := decodeExactly(args, payload)
		if !ok {
			continue
		}

		ctoken := *abi.ConvertType(values[0], new(CanonicalERC20)).(*CanonicalERC20)
		sent, ok := values[3].(*big.Int)

		if ok && utf8.ValidString(ctoken.Symbol) && utf8.ValidString(ctoken.Name) {
			return EventTypeSendERC20, ctoken, sent, nil
		}
	}

	if values, ok := decodeExactly(erc721PayloadArgs, payload); ok {
		ctoken := *abi.ConvertType(values[0], new(CanonicalNFT)).(*CanonicalNFT)

		if utf8.ValidString(ctoken.Symbol) && utf8.ValidString(ctoken.Name) {
			return EventTypeSendERC721, ctoken, big.NewInt(1), nil
		}
	}

	if values, ok := decodeExactly(erc1155PayloadArgs, payload); ok {
		ctoken := *abi.ConvertType(values[0], new(CanonicalNFT)).(*CanonicalNFT)
		amounts, ok := values[4].([]*big.Int)

		if ok && utf8.ValidString(ctoken.Symbol) && utf8.ValidString(ctoken.Name) {
			return EventTypeSendERC1155, ctoken, sumAmounts(amounts), nil
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
