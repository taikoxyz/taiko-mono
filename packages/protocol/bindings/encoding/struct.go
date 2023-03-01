package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/beacon"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-client/bindings"
)

type BlockHeader struct {
	ParentHash       [32]byte
	OmmersHash       [32]byte
	Beneficiary      common.Address
	StateRoot        [32]byte
	TransactionsRoot [32]byte
	ReceiptsRoot     [32]byte
	LogsBloom        [8][32]byte
	Difficulty       *big.Int
	Height           *big.Int
	GasLimit         uint64
	GasUsed          uint64
	Timestamp        uint64
	ExtraData        []byte
	MixHash          [32]byte
	Nonce            uint64
	BaseFeePerGas    *big.Int
}

type TaikoL1Evidence struct {
	Meta     bindings.TaikoDataBlockMetadata
	Header   BlockHeader
	Prover   common.Address
	Proofs   [][]byte
	Circuits uint16
}

// FromGethHeader converts a GETH *types.Header to *BlockHeader.
func FromGethHeader(header *types.Header) *BlockHeader {
	baseFeePerGas := header.BaseFee
	if baseFeePerGas == nil {
		baseFeePerGas = common.Big0
	}
	return &BlockHeader{
		ParentHash:       header.ParentHash,
		OmmersHash:       header.UncleHash,
		Beneficiary:      header.Coinbase,
		StateRoot:        header.Root,
		TransactionsRoot: header.TxHash,
		ReceiptsRoot:     header.ReceiptHash,
		LogsBloom:        BloomToBytes(header.Bloom),
		Difficulty:       header.Difficulty,
		Height:           header.Number,
		GasLimit:         header.GasLimit,
		GasUsed:          header.GasUsed,
		Timestamp:        header.Time,
		ExtraData:        header.Extra,
		MixHash:          header.MixDigest,
		Nonce:            header.Nonce.Uint64(),
		BaseFeePerGas:    baseFeePerGas,
	}
}

// ToGethHeader converts a *BlockHeader to GETH *types.Header.
func ToGethHeader(header *BlockHeader) *types.Header {
	baseFeePerGas := header.BaseFeePerGas
	if baseFeePerGas.Cmp(common.Big0) == 0 {
		baseFeePerGas = nil
	}
	return &types.Header{
		ParentHash:  header.ParentHash,
		UncleHash:   header.OmmersHash,
		Coinbase:    header.Beneficiary,
		Root:        header.StateRoot,
		TxHash:      header.TransactionsRoot,
		ReceiptHash: header.ReceiptsRoot,
		Bloom:       BytesToBloom(header.LogsBloom),
		Difficulty:  header.Difficulty,
		Number:      header.Height,
		GasLimit:    header.GasLimit,
		GasUsed:     header.GasUsed,
		Time:        header.Timestamp,
		Extra:       header.ExtraData,
		MixDigest:   header.MixHash,
		Nonce:       types.EncodeNonce(header.Nonce),
		BaseFee:     baseFeePerGas,
	}
}

// ToExecutableDataV1 converts a GETH *types.Header to *beacon.ExecutableDataV1.
func ToExecutableDataV1(header *types.Header) *beacon.ExecutableDataV1 {
	return &beacon.ExecutableDataV1{
		ParentHash:    header.ParentHash,
		FeeRecipient:  header.Coinbase,
		StateRoot:     header.Root,
		ReceiptsRoot:  header.ReceiptHash,
		LogsBloom:     header.Bloom.Bytes(),
		Random:        header.MixDigest,
		Number:        header.Number.Uint64(),
		GasLimit:      header.GasLimit,
		GasUsed:       header.GasUsed,
		Timestamp:     header.Time,
		ExtraData:     header.Extra,
		BaseFeePerGas: header.BaseFee,
		BlockHash:     header.Hash(),
		TxHash:        header.TxHash,
	}
}

// BloomToBytes converts a types.Bloom to [8][32]byte slice.
func BloomToBytes(bloom types.Bloom) [8][32]byte {
	b := [8][32]byte{}

	for i := 0; i < 8; i++ {
		copy(b[i][:], bloom[i*32:(i+1)*32])
	}

	return b
}

// BytesToBloom converts a [8][32]byte slice to types.Bloom.
func BytesToBloom(b [8][32]byte) types.Bloom {
	bytes := []byte{}

	for i := 0; i < 8; i++ {
		bytes = append(bytes, b[i][:]...)
	}

	return types.BytesToBloom(bytes)
}
