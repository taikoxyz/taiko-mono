package relayer

import (
	"encoding/json"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

func LogsBloomToBytes(logsBloom types.Bloom) [8][32]byte {
	var ret = [8][32]byte{}
	bloom := [256]byte(logsBloom)
	index := 0
	for i := 0; i < 256; i += 32 {
		end := i + 31
		b := bloom[i:end]
		var r [32]byte
		copy(r[:], b)
		ret[index] = r
		index++
	}
	return ret
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
}

type SignalProof struct {
	Header BlockHeader `abi:"header"`
	Proof  []byte      `abi:"proof"`
}

var (
	StorageProofAbiString = `[{"components":[{"type":"bytes", "name":"accountProof"}, {"type":"bytes", "name":"storageProof"}], "type":"tuple"}]`
)
var (
	SignalProofAbiString = `[{"components": [{ "type": "tuple","components": [
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
func StringToABI(s string) (abi.ABI, error) {
	inDef := fmt.Sprintf(`[{ "name" : "method", "type": "function", "inputs": %s}]`, s)
	dec := json.NewDecoder(strings.NewReader(inDef))

	var abi abi.ABI
	if err := dec.Decode(&abi); err != nil {
		return abi, err
	}
	return abi, nil
}
