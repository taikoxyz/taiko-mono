package indexer

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

// var (
// 	signalProofType  = abi.MustNewType("tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce) header, bytes proof)")
// 	storageProofType = abi.MustNewType("tuple(bytes, bytes)")
// )

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
}

type SignalProof struct {
	Header BlockHeader `abi:"header"`
	Proof  []byte      `abi:"proof"`
}

var (
	storageProofAbiString = `[{"components":[{"type":"bytes", "name":"accountProof"}, {"type":"bytes", "name":"storageProof"}], "type":"tuple"}]`
)
var (
	signalProofAbiString = `[{"components": [{ "type": "tuple","components": [
	{"name": "parentHash","type": "bytes32"},
	{"name": "ommersHash","type": "bytes32"},
	{"name": "beneficiary","type": "address"},
	{"name": "stateRoot","type": "bytes32"},
	{"name": "transactionsRoot","type": "bytes32"},
	{"name": "receiptsRoot","type": "bytes32"},
	{"name": "logsBloom","type": "bytes32[8]"},
	{"name": "difficulty","type": "uint256"},
	{"name": "height","type": "uint128"},
	{"name": "gasLimit","type": "uint64"},
	{"name": "gasUsed","type": "uint64"},
	{"name": "timestamp","type": "uint64"},
	{"name": "extraData","type": "bytes"},
	{"name": "mixHash","type": "bytes32"},
	{"name": "nonce","type": "uint64"}],
	"name": "header", "type": "tuple"},
	{"name": "proof", "type": "bytes"}], "type": "tuple"}]`
)

// JSON returns a parsed ABI interface and error if it failed.
func JSON(reader io.Reader) (abi.ABI, error) {
	dec := json.NewDecoder(reader)

	var abi abi.ABI
	if err := dec.Decode(&abi); err != nil {
		return abi, err
	}
	return abi, nil
}

// below taken from https://github.com/vocdoni/storage-proofs-eth-go
type QuantityBytes []byte

func (q QuantityBytes) MarshalText() ([]byte, error) {
	return []byte(fmt.Sprintf("0x%v",
		new(big.Int).SetBytes(q).Text(16))), nil
}

func (q *QuantityBytes) UnmarshalText(input []byte) error {
	input = bytes.TrimPrefix(input, []byte("0x"))
	v, ok := new(big.Int).SetString(string(input), 16)
	if !ok {
		return fmt.Errorf("invalid hex input")
	}
	*q = v.Bytes()
	return nil
}

type SliceData [][]byte

func (s SliceData) MarshalJSON() ([]byte, error) {
	bs := make([]hexutil.Bytes, len(s))
	for i, b := range s {
		bs[i] = b
	}
	return json.Marshal(bs)
}

func (s *SliceData) UnmarshalJSON(data []byte) error {
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
	AccountProof SliceData       `json:"accountProof"`
	StorageProof []StorageResult `json:"storageProof"`
}

// StorageResult is an object from StorageProof that contains a proof of
// storage.
type StorageResult struct {
	Key   QuantityBytes `json:"key"`
	Value QuantityBytes `json:"value"`
	Proof SliceData     `json:"proof"`
}
