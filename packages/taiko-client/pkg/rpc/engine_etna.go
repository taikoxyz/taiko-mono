package rpc

import (
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/miner"
)

// IsEtna returns whether the given chain and timestamp are inside the Etna fork, which removes the
// anchor transaction and commits each block's L1 anchor block hash as its parentBeaconBlockRoot.
func IsEtna(chainID *big.Int, timestamp uint64) bool {
	config := taikoChainConfig(chainID)
	return config != nil && config.IsEtna(timestamp)
}

// AnchorGasReserve returns the gas a block at the given timestamp adds on top of its manifest gas
// limit for the anchor transaction: consensus.AnchorV3V4GasLimit before Etna, zero from Etna on.
func AnchorGasReserve(chainID *big.Int, timestamp uint64) uint64 {
	if IsEtna(chainID, timestamp) {
		return 0
	}

	return consensus.AnchorV3V4GasLimit
}

// ManifestGasLimit returns the gas limit a built L2 block was derived from, the protocol's
// `parent.metadata.gasLimit`: the header gas limit minus the anchor gas reserve for a non-genesis
// block before Etna, and the header gas limit otherwise.
func ManifestGasLimit(chainID *big.Int, header *types.Header) uint64 {
	if header.Number.Sign() == 0 || IsEtna(chainID, header.Time) {
		return header.GasLimit
	}

	return header.GasLimit - consensus.AnchorV3V4GasLimit
}

// BuildPayloadArgsID computes the driver's payload fingerprint stored as l1Origin.buildPayloadArgsId, which the
// driver recomputes to detect blocks it already inserted. Blocks before Etna use the original V2 fingerprint;
// Etna blocks (a non-nil parentBeaconBlockRoot) also bind the root and use the V3 version byte.
func BuildPayloadArgsID(
	parentHash common.Hash,
	timestamp uint64,
	feeRecipient common.Address,
	mixHash common.Hash,
	extraData []byte,
	txListHash common.Hash,
	parentBeaconBlockRoot *common.Hash,
) engine.PayloadID {
	args := &miner.BuildPayloadArgs{
		Parent:       parentHash,
		Timestamp:    timestamp,
		FeeRecipient: feeRecipient,
		Random:       mixHash,
		Withdrawals:  make([]*types.Withdrawal, 0),
		Version:      engine.PayloadV2,
		TxListHash:   &txListHash,
		Extra:        extraData,
	}
	if parentBeaconBlockRoot != nil {
		args.BeaconRoot = parentBeaconBlockRoot
		args.Version = engine.PayloadV3
	}
	return args.Id()
}

// TaikoExecutionPayloadV3 is the engine_newPayloadV4 payload object for Etna blocks: the standard
// Cancun execution payload fields plus Taiko's finalized zk gas in headerDifficulty, encoded as a
// decimal JSON number. alethia-reth rejects any other property, including the extra Taiko fields
// that engine.ExecutableData always serializes.
type TaikoExecutionPayloadV3 struct {
	ParentHash       common.Hash         `json:"parentHash"`
	FeeRecipient     common.Address      `json:"feeRecipient"`
	StateRoot        common.Hash         `json:"stateRoot"`
	ReceiptsRoot     common.Hash         `json:"receiptsRoot"`
	LogsBloom        hexutil.Bytes       `json:"logsBloom"`
	PrevRandao       common.Hash         `json:"prevRandao"`
	BlockNumber      hexutil.Uint64      `json:"blockNumber"`
	GasLimit         hexutil.Uint64      `json:"gasLimit"`
	GasUsed          hexutil.Uint64      `json:"gasUsed"`
	Timestamp        hexutil.Uint64      `json:"timestamp"`
	ExtraData        hexutil.Bytes       `json:"extraData"`
	BaseFeePerGas    *hexutil.Big        `json:"baseFeePerGas"`
	BlockHash        common.Hash         `json:"blockHash"`
	Transactions     []hexutil.Bytes     `json:"transactions"`
	Withdrawals      []*types.Withdrawal `json:"withdrawals"`
	BlobGasUsed      hexutil.Uint64      `json:"blobGasUsed"`
	ExcessBlobGas    hexutil.Uint64      `json:"excessBlobGas"`
	HeaderDifficulty uint64              `json:"headerDifficulty"`
}

// NewTaikoExecutionPayloadV3 converts a normalized execution payload, whose HeaderDifficulty already
// holds the block's zk gas, into the engine_newPayloadV4 payload object.
func NewTaikoExecutionPayloadV3(data *engine.ExecutableData) (*TaikoExecutionPayloadV3, error) {
	if data == nil {
		return nil, errors.New("empty execution payload")
	}
	if data.HeaderDifficulty == nil || !data.HeaderDifficulty.IsUint64() {
		return nil, fmt.Errorf("invalid header difficulty %v for Etna payload %d", data.HeaderDifficulty, data.Number)
	}
	if data.BaseFeePerGas == nil {
		return nil, fmt.Errorf("missing base fee for Etna payload %d", data.Number)
	}

	// A nil slice would serialize as null, but the execution engine requires complete arrays.
	txs := make([]hexutil.Bytes, len(data.Transactions))
	for i, tx := range data.Transactions {
		txs[i] = tx
	}
	withdrawals := data.Withdrawals
	if withdrawals == nil {
		withdrawals = make([]*types.Withdrawal, 0)
	}
	var blobGasUsed, excessBlobGas uint64
	if data.BlobGasUsed != nil {
		blobGasUsed = *data.BlobGasUsed
	}
	if data.ExcessBlobGas != nil {
		excessBlobGas = *data.ExcessBlobGas
	}

	return &TaikoExecutionPayloadV3{
		ParentHash:       data.ParentHash,
		FeeRecipient:     data.FeeRecipient,
		StateRoot:        data.StateRoot,
		ReceiptsRoot:     data.ReceiptsRoot,
		LogsBloom:        data.LogsBloom,
		PrevRandao:       data.Random,
		BlockNumber:      hexutil.Uint64(data.Number),
		GasLimit:         hexutil.Uint64(data.GasLimit),
		GasUsed:          hexutil.Uint64(data.GasUsed),
		Timestamp:        hexutil.Uint64(data.Timestamp),
		ExtraData:        data.ExtraData,
		BaseFeePerGas:    (*hexutil.Big)(data.BaseFeePerGas),
		BlockHash:        data.BlockHash,
		Transactions:     txs,
		Withdrawals:      withdrawals,
		BlobGasUsed:      hexutil.Uint64(blobGasUsed),
		ExcessBlobGas:    hexutil.Uint64(excessBlobGas),
		HeaderDifficulty: data.HeaderDifficulty.Uint64(),
	}, nil
}

// TxPoolBlockContext is the trailing blockContext argument of the taikoAuth tx-pool methods: the
// target block the execution engine simulates candidate transactions for. alethia-reth requires it
// once the parent block is at or after Etna.
type TxPoolBlockContext struct {
	Timestamp             hexutil.Uint64 `json:"timestamp"`
	ParentBeaconBlockRoot common.Hash    `json:"parentBeaconBlockRoot"`
	ExtraData             hexutil.Bytes  `json:"extraData"`
}
