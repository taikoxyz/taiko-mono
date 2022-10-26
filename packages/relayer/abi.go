package relayer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
)

type BlockHeader struct {
	ParentHash       common.Hash
	OmmersHash       common.Hash
	Beneficiary      common.Address
	StateRoot        common.Hash
	TransactionsRoot common.Hash
	ReceiptsRoot     common.Hash
	Difficulty       *big.Int
	Height           *big.Int
	GasLimit         *big.Int
	GasUsed          *big.Int
	Timestamp        *big.Int
	ExtraData        []byte
	MixHash          common.Hash
	Nonce            *big.Int
}

type SignalProof struct {
	Header BlockHeader
	Proof  []byte
}

var (
	BlockHeaderABIType, _ = abi.NewType("tuple", "BlockHeader", []abi.ArgumentMarshaling{
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
	})

	SignalProofABIType, _ = abi.NewType("tuple", "SignalProof", []abi.ArgumentMarshaling{
		{
			Name: "header",
			Type: "BlockHeader",
		},
		{
			Name: "proof",
			Type: "bytes",
		},
	})
)
