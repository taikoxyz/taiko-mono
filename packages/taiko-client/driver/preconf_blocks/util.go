package preconfblocks

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"math/big"
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

// payloadPrevRandao returns the canonical preconfirmation randomness carrier.
func payloadPrevRandao(mixDigest common.Hash) eth.Bytes32 {
	return eth.Bytes32(mixDigest)
}

// executionPayloadEnvelope builds an ExecutionPayloadEnvelope from normalized payload fields.
func executionPayloadEnvelope(
	baseFee *big.Int,
	parentHash common.Hash,
	feeRecipient common.Address,
	extraData []byte,
	prevRandao eth.Bytes32,
	blockNumber uint64,
	gasLimit uint64,
	gasUsed uint64,
	timestamp uint64,
	blockHash common.Hash,
	txs []eth.Data,
	endOfSequencing *bool,
	isForcedInclusion *bool,
	signature *[65]byte,
	headerDifficulty *big.Int,
) (*eth.ExecutionPayloadEnvelope, error) {
	// If the base fee is too large to fit in a uint256, we should return an error instead of silently truncating it.
	var u256 uint256.Int
	if overflow := u256.SetFromBig(baseFee); overflow {
		return nil, fmt.Errorf("failed to convert base fee to uint256: %v", overflow)
	}

	envelope := &eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{
			BaseFeePerGas: eth.Uint256Quantity(u256),
			ParentHash:    parentHash,
			FeeRecipient:  feeRecipient,
			ExtraData:     extraData,
			PrevRandao:    prevRandao,
			BlockNumber:   eth.Uint64Quantity(blockNumber),
			GasLimit:      eth.Uint64Quantity(gasLimit),
			GasUsed:       eth.Uint64Quantity(gasUsed),
			Timestamp:     eth.Uint64Quantity(timestamp),
			BlockHash:     blockHash,
			Transactions:  txs,
		},
		EndOfSequencing:   endOfSequencing,
		IsForcedInclusion: isForcedInclusion,
		Signature:         signature,
	}
	if headerDifficulty != nil && headerDifficulty.Cmp(common.Big0) > 0 {
		envelope.HeaderDifficulty = new(big.Int).Set(headerDifficulty)
	}
	return envelope, nil
}

// blockToEnvelope converts a block to an ExecutionPayloadEnvelope.
func blockToEnvelope(
	block *types.Block,
	endOfSequencing *bool,
	isForcedInclusion *bool,
	signature *[65]byte,
) (*eth.ExecutionPayloadEnvelope, error) {
	txs, err := utils.EncodeAndCompressTxList(block.Transactions())
	if err != nil {
		return nil, fmt.Errorf("failed to encode and compress transaction list: %w", err)
	}

	return executionPayloadEnvelope(
		block.BaseFee(),
		block.ParentHash(),
		block.Coinbase(),
		block.Extra(),
		payloadPrevRandao(block.MixDigest()),
		block.NumberU64(),
		block.GasLimit(),
		block.GasUsed(),
		block.Time(),
		block.Hash(),
		[]eth.Data{hexutil.Bytes(txs)},
		endOfSequencing,
		isForcedInclusion,
		signature,
		block.Difficulty(),
	)
}

// headerToEnvelope converts a sealed header to an ExecutionPayloadEnvelope.
func headerToEnvelope(
	header *types.Header,
	txs []eth.Data,
	endOfSequencing *bool,
	isForcedInclusion *bool,
	signature *[65]byte,
) (*eth.ExecutionPayloadEnvelope, error) {
	return executionPayloadEnvelope(
		header.BaseFee,
		header.ParentHash,
		header.Coinbase,
		header.Extra,
		payloadPrevRandao(header.MixDigest),
		header.Number.Uint64(),
		header.GasLimit,
		header.GasUsed,
		header.Time,
		header.Hash(),
		txs,
		endOfSequencing,
		isForcedInclusion,
		signature,
		header.Difficulty,
	)
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
