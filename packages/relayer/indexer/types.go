package indexer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/umbracle/ethgo/abi"
)

var (
	signalProofType  = abi.MustNewType("tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce) header, bytes proof)")
	storageProofType = abi.MustNewType("tuple(bytes accountProof, bytes storageProof)")
)

type Proof struct {
	AccountProof []byte `abi:"accountProof"`
	StorageProof []byte `abi:"storageProof"`
}

type BlockHeader struct {
	ParentHash       common.Hash    `abi:"parentHash"`
	OmmersHash       common.Hash    `abi:"ommersHash"`
	Beneficiary      common.Address `abi:"beneficiary"`
	StateRoot        common.Hash    `abi:"stateRoot"`
	TransactionsRoot common.Hash    `abi:"transactionsRoot"`
	ReceiptsRoot     common.Hash    `abi:"receiptsRoot"`
	Difficulty       *big.Int       `abi:"difficulty"`
	Height           *big.Int       `abi:"height"`
	GasLimit         uint64         `abi:"gasLimit"`
	GasUsed          uint64         `abi:"gasUsed"`
	Timestamp        uint64         `abi:"timestamp"`
	ExtraData        []byte         `abi:"extraData"`
	LogsBloom        [8][32]byte    `abi:"logsBloom"`
	MixHash          common.Hash    `abi:"mixHash"`
	Nonce            uint64         `abi:"nonce"`
}

type SignalProof struct {
	Header BlockHeader `abi:"header"`
	Proof  []byte      `abi:"proof"`
}
