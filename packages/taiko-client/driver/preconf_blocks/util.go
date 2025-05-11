package preconfblocks

import (
	"fmt"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/holiman/uint256"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// blockToEnvelope converts a block to an ExecutionPayloadEnvelope.
func blockToEnvelope(block *types.Block, endOfSequencing *bool) (*eth.ExecutionPayloadEnvelope, error) {
	var u256 uint256.Int
	if overflow := u256.SetFromBig(block.BaseFee()); overflow {
		return nil, fmt.Errorf("failed to convert base fee to uint256: %w", overflow)
	}
	txs, err := utils.EncodeAndCompressTxList(block.Transactions())
	if err != nil {
		return nil, err
	}

	return &eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{
			BaseFeePerGas: eth.Uint256Quantity(u256),
			ParentHash:    block.ParentHash(),
			FeeRecipient:  block.Coinbase(),
			ExtraData:     block.Extra(),
			PrevRandao:    eth.Bytes32(block.MixDigest()),
			BlockNumber:   eth.Uint64Quantity(block.NumberU64()),
			GasLimit:      eth.Uint64Quantity(block.GasLimit()),
			GasUsed:       eth.Uint64Quantity(block.GasUsed()),
			Timestamp:     eth.Uint64Quantity(block.Time()),
			BlockHash:     block.Hash(),
			Transactions:  []eth.Data{hexutil.Bytes(txs)},
		},
		EndOfSequencing: endOfSequencing,
	}, nil
}
