package encoding

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func BlockToBlockHeader(block *types.Block) BlockHeader {
	baseFee := block.BaseFee()
	if baseFee == nil {
		baseFee = common.Big0
	}

	withdrawalsRoot := relayer.ZeroHash

	if block.Header().WithdrawalsHash != nil {
		withdrawalsRoot = *block.Header().WithdrawalsHash
	}

	return BlockHeader{
		ParentHash:       block.ParentHash(),
		OmmersHash:       block.UncleHash(),
		Beneficiary:      block.Coinbase(),
		TransactionsRoot: block.TxHash(),
		ReceiptsRoot:     block.ReceiptHash(),
		Difficulty:       block.Difficulty(),
		Height:           block.Number(),
		GasLimit:         block.GasLimit(),
		GasUsed:          block.GasUsed(),
		Timestamp:        block.Time(),
		ExtraData:        block.Extra(),
		MixHash:          block.MixDigest(),
		Nonce:            block.Nonce(),
		StateRoot:        block.Root(),
		LogsBloom:        logsBloomToBytes(block.Bloom()),
		BaseFeePerGas:    baseFee,
		WithdrawalsRoot:  withdrawalsRoot,
	}
}
