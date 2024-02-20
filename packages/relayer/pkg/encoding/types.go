package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
)

var hopProofsT abi.Type
var err error

func init() {
	hopProofsT, err = abi.NewType("tuple[]", "tuple[]", hopComponents)
	if err != nil {
		panic(err)
	}
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
	WithdrawalsRoot  [32]byte       `abi:"withdrawalsRoot"`
}

type HopProof struct {
	ChainID      uint64   `abi:"chainId"`
	BlockID      uint64   `abi:"blockId"`
	RootHash     [32]byte `abi:"rootHash"`
	CacheOption  *big.Int `abi:"cacheOption"`
	AccountProof [][]byte `abi:"accountProof"`
	StorageProof [][]byte `abi:"storageProof"`
}

var hopComponents = []abi.ArgumentMarshaling{
	{
		Name: "chainId",
		Type: "uint64",
	},
	{
		Name: "blockId",
		Type: "uint64",
	},
	{
		Name: "rootHash",
		Type: "bytes32",
	},
	{
		Name: "cacheOption",
		Type: "uint256",
	},
	{
		Name: "accountProof",
		Type: "bytes[]",
	},
	{
		Name: "storageProof",
		Type: "bytes[]",
	},
}
