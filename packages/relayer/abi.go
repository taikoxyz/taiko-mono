package relayer

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
)

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
