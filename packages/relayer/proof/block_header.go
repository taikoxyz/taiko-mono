package proof

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

// blockHeader converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (p *Prover) blockHeader(ctx context.Context, blockHash common.Hash) (BlockHeader, error) {
	block, err := p.ethClient.BlockByHash(ctx, blockHash)
	if err != nil {
		return BlockHeader{}, errors.Wrap(err, "p.ethClient.GetBlockByNumber")
	}

	log.Infof("block Hash: %v", hexutil.Encode(block.Hash().Bytes()))

	return blockToBlockHeader(ctx, block)
}

func blockToBlockHeader(ctx context.Context, block *types.Block) (BlockHeader, error) {
	logsBloom, err := logsBloomToBytes(block.Bloom())
	if err != nil {
		return BlockHeader{}, errors.Wrap(err, "proof.LogsBloomToBytes")
	}

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
	log.Infof(`blockheader: parentHash: %v, 
	ommersHash: %v, beneficiary: %v, transactionsRoot: %v, 
	receiptsRoot: %v, difficulty: %v, height: %v, gasLimit: %v, gasUsed: %v, timestamp :%v,
	extraData: %v, mixHash: %v, nonce: %v, stateRoot: %v`, hexutil.Encode(h.ParentHash[:]), hexutil.Encode(h.OmmersHash[:]),
		h.Beneficiary, hexutil.Encode(h.TransactionsRoot[:]), hexutil.Encode(h.ReceiptsRoot[:]), h.Difficulty.Int64(), h.Height.Int64(), h.GasLimit, h.GasUsed,
		h.Timestamp, hexutil.Encode(h.ExtraData), hexutil.Encode(h.MixHash[:]), h.Nonce, hexutil.Encode(h.StateRoot[:]))

	for _, bloom := range logsBloom {
		log.Infof("bloom: %v", hexutil.Encode(bloom[:]))
	}
	return h, nil
}
