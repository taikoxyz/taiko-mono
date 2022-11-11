package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
)

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
