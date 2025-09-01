package preconfblocks

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/holiman/uint256"
	"github.com/libp2p/go-libp2p/core/peer"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// blockToEnvelope converts a block to an ExecutionPayloadEnvelope.
func blockToEnvelope(
	block *types.Block,
	endOfSequencing *bool,
	isForcedInclusion *bool,
	signature *[65]byte,
) (*eth.ExecutionPayloadEnvelope, error) {
	var u256 uint256.Int
	if overflow := u256.SetFromBig(block.BaseFee()); overflow {
		return nil, fmt.Errorf("failed to convert base fee to uint256: %v", overflow)
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
		EndOfSequencing:   endOfSequencing,
		IsForcedInclusion: isForcedInclusion,
		Signature:         signature,
	}, nil
}

// checkMessageBlockNumber checks if the block number of the message is greater than the
// current head L1 origin block ID, if there is no head L1 origin stored in L2 EE, it returns nil.
func checkMessageBlockNumber(
	ctx context.Context,
	rpc *rpc.Client,
	msg *eth.ExecutionPayloadEnvelope,
) (*rawdb.L1Origin, error) {
	headL1Origin, err := rpc.L2.HeadL1Origin(ctx)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return nil, fmt.Errorf("failed to fetch head L1 origin: %w", err)
	}

	if headL1Origin != nil && uint64(msg.ExecutionPayload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
		return nil, fmt.Errorf(
			"preconfirmation block ID (%d) is less than or equal to the current head L1 origin block ID (%d)",
			msg.ExecutionPayload.BlockNumber,
			headL1Origin.BlockID,
		)
	}

	return headL1Origin, nil
}

// deterministicJitter returns a deterministic jitter based on the peer ID and block hash,
// such that we dont immediately reply to messages.
func deterministicJitter(self peer.ID, h common.Hash, max time.Duration) time.Duration {
	b := append([]byte(self), h.Bytes()...)
	sum := sha256.Sum256(b)
	v := binary.LittleEndian.Uint64(sum[:8])
	return time.Duration(v % uint64(max))
}
