package proof

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

// blockHeader converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (p *Prover) blockHeader(ctx context.Context, blockNumber int64) (BlockHeader, error) {
	block, err := p.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return BlockHeader{}, errors.Wrap(err, "p.ethClient.GetBlockByNumber")
	}
	log.Infof("state root: %v", block.Root().String())

	return blockToBlockHeader(ctx, block)
}

func blockToBlockHeader(ctx context.Context, block *types.Block) (BlockHeader, error) {
	logsBloom, err := logsBloomToBytes(block.Bloom())
	if err != nil {
		return BlockHeader{}, errors.Wrap(err, "proof.LogsBloomToBytes")
	}

	log.Infof("block stuff : %v, %v, %v", block.Hash().String(), block.GasLimit(), block.GasUsed())
	h := BlockHeader{
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
		LogsBloom:        logsBloom,
	}
	log.Infof("blockheader stuff: %v, %v", block.GasLimit(), block.GasUsed())
	return h, nil
}
