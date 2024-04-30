package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

var hopProofsT abi.Type
var err error

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

type CacheOption uint8

const (
	CACHE_NOTHING     = iota
	CACHE_SIGNAL_ROOT = iota
	CACHE_STATE_ROOT  = iota
	CACHE_BOTH        = iota
)

type HopProof struct {
	ChainID      uint64   `abi:"chainId"`
	BlockID      uint64   `abi:"blockId"`
	RootHash     [32]byte `abi:"rootHash"`
	CacheOption  uint8    `abi:"cacheOption"`
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
		Type: "uint8",
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

var BridgeABI *abi.ABI

func init() {
	hopProofsT, err = abi.NewType("tuple[]", "tuple[]", hopComponents)
	if err != nil {
		panic(err)
	}

	if BridgeABI, err = bridge.BridgeMetaData.GetAbi(); err != nil {
		log.Crit("Get Bridge ABI error", "error", err)
	}
}
