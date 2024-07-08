package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// Tier IDs defined in protocol.
var (
	TierOptimisticID       uint16 = 100
	TierSgxID              uint16 = 200
	TierSgxAndZkVMID       uint16 = 300
	TierGuardianMinorityID uint16 = 900
	TierGuardianMajorityID uint16 = 1000
	ProtocolTiers                 = []uint16{
		TierOptimisticID,
		TierSgxID,
		TierSgxAndZkVMID,
		TierGuardianMinorityID,
		TierGuardianMajorityID,
	}
	GoldenTouchPrivKey = "92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"
)

// HookCall should be same with TaikoData.HookCall
type HookCall struct {
	Hook common.Address
	Data []byte
}

// BlockParams should be same with TaikoData.BlockParams.
type BlockParams struct {
	AssignedProver common.Address
	Coinbase       common.Address
	ExtraData      [32]byte
	ParentMetaHash [32]byte
	HookCalls      []HookCall
	Signature      []byte
}

// BlockParams2 should be same with TaikoData.BlockParams2.
type BlockParams2 struct {
	Coinbase       common.Address
	ExtraData      [32]byte
	ParentMetaHash [32]byte
	AnchorBlockID  uint64
	Timestamp      uint64
}

// TierFee should be same with TaikoData.TierFee.
type TierFee struct {
	Tier uint16
	Fee  *big.Int
}

// ToExecutableData converts a GETH *types.Header to *engine.ExecutableData.
func ToExecutableData(header *types.Header) *engine.ExecutableData {
	executableData := &engine.ExecutableData{
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

	if header.WithdrawalsHash != nil {
		executableData.WithdrawalsHash = *header.WithdrawalsHash
	}

	return executableData
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
