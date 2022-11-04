package proof

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

type Bytes []byte

// MarshalText implements encoding.TextMarshaler
func (q Bytes) MarshalText() ([]byte, error) {
	return []byte(fmt.Sprintf("0x%v",
		new(big.Int).SetBytes(q).Text(16))), nil
}

// UnmarshalText implements encoding.TextUnmarshaler.
func (q *Bytes) UnmarshalText(input []byte) error {
	input = bytes.TrimPrefix(input, []byte("0x"))
	v, ok := new(big.Int).SetString(string(input), 16)
	if !ok {
		return fmt.Errorf("invalid hex input")
	}
	*q = v.Bytes()
	return nil
}

type Slice [][]byte

// MarshalText implements encoding.TextMarshaler
func (s Slice) MarshalJSON() ([]byte, error) {
	bs := make([]hexutil.Bytes, len(s))
	for i, b := range s {
		bs[i] = b
	}
	return json.Marshal(bs)
}

// UnmarshalText implements encoding.TextUnmarshaler.
func (s *Slice) UnmarshalJSON(data []byte) error {
	var bs []hexutil.Bytes
	if err := json.Unmarshal(data, &bs); err != nil {
		return err
	}
	*s = make([][]byte, len(bs))
	for i, b := range bs {
		(*s)[i] = b
	}
	return nil
}

type StorageProof struct {
	Height       *big.Int        `json:"height"`
	Address      common.Address  `json:"address"`
	Balance      *hexutil.Big    `json:"balance"`
	CodeHash     common.Hash     `json:"codeHash"`
	Nonce        hexutil.Uint64  `json:"nonce"`
	StateRoot    common.Hash     `json:"stateRoot"`
	StorageHash  common.Hash     `json:"storageHash"`
	AccountProof Slice           `json:"accountProof"`
	StorageProof []StorageResult `json:"storageProof"`
}

// StorageResult is an object from StorageProof that contains a proof of
// storage.
type StorageResult struct {
	Key   Bytes `json:"key"`
	Value Bytes `json:"value"`
	Proof Slice `json:"proof"`
}

type Proof struct {
	AccountProof []byte `abi:"accountProof"`
	StorageProof []byte `abi:"storageProof"`
}

type BlockHeader struct {
	ParentHash       [32]byte       `abi:"parentHash"`
	OmmersHash       [32]byte       `abi:"ommersHash"`
	Beneficiary      common.Address `abi:"beneficiary"`
	StateRoot        [32]byte       `abi:"stateRoot"`
	TransactionsRoot [32]byte       `abi:"transactionsRoot"`
	ReceiptsRoot     [32]byte       `abi:"receiptsRoot"`
	LogsBloom        [8][32]byte    `abi:"logsBloom"`
	Difficulty       *big.Int       `abi:"difficulty"`
	Height           *big.Int       `abi:"height"`
	GasLimit         uint64         `abi:"gasLimit"`
	GasUsed          uint64         `abi:"gasUsed"`
	Timestamp        uint64         `abi:"timestamp"`
	ExtraData        []byte         `abi:"extraData"`
	MixHash          [32]byte       `abi:"mixHash"`
	Nonce            uint64         `abi:"nonce"`
	BaseFeePerGas    *big.Int       `abi:"baseFeePerGas"`
}

type SignalProof struct {
	Header BlockHeader `abi:"header"`
	Proof  []byte      `abi:"proof"`
}

var signalProofT, _ = abi.NewType("tuple", "", []abi.ArgumentMarshaling{
	{
		Name: "header",
		Type: "tuple",
		Components: []abi.ArgumentMarshaling{
			{
				Name: "parentHash",
				Type: "bytes32",
			},
			{
				Name: "ommersHash",
				Type: "bytes32",
			},
			{
				Name: "beneficiary",
				Type: "address",
			},
			{
				Name: "stateRoot",
				Type: "bytes32",
			},
			{
				Name: "transactionsRoot",
				Type: "bytes32",
			},
			{
				Name: "receiptsRoot",
				Type: "bytes32",
			},
			{
				Name: "logsBloom",
				Type: "bytes32[8]",
			},
			{
				Name: "difficulty",
				Type: "uint256",
			},
			{
				Name: "height",
				Type: "uint128",
			},
			{
				Name: "gasLimit",
				Type: "uint64",
			},
			{
				Name: "gasUsed",
				Type: "uint64",
			},
			{
				Name: "timestamp",
				Type: "uint64",
			},
			{
				Name: "extraData",
				Type: "bytes",
			},
			{
				Name: "mixHash",
				Type: "bytes32",
			},
			{
				Name: "nonce",
				Type: "uint64",
			},
			{
				Name: "baseFeePerGas",
				Type: "uint256",
			},
		},
	},
	{
		Name: "proof",
		Type: "bytes",
	},
})

var bytesT, _ = abi.NewType("bytes", "", nil)
