package proof

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/pkg/errors"
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
		return errors.New("invalid hex input")
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
