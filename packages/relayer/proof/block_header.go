package proof

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer/encoding"
)

// blockHeader fetches block via rpc, then converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (p *Prover) blockHeader(ctx context.Context, blockHash common.Hash) (encoding.BlockHeader, error) {
	h, err := p.ethClient.BlockByHash(ctx, blockHash)
	if err != nil {
		return encoding.BlockHeader{}, errors.Wrap(err, "p.ethClient.GetBlockByNumber")
	}

	log.Infof("block Hash: %v", hexutil.Encode(h.Hash().Bytes()))
	log.Infof(`blockheader: parentHash: %v, 
	ommersHash: %v, beneficiary: %v, transactionsRoot: %v, 
	receiptsRoot: %v, difficulty: %v, height: %v, gasLimit: %v, gasUsed: %v, timestamp :%v,
	extraData: %v, mixHash: %v, nonce: %v, stateRoot: %v, baseFee: %v`, hexutil.Encode(h.ParentHash().Bytes()[:]), hexutil.Encode(h.UncleHash().Bytes()[:]),
		h.Coinbase().String(), hexutil.Encode(h.TxHash().Bytes()[:]), hexutil.Encode(h.ReceiptHash().Bytes()[:]), h.Difficulty().Int64(), h.NumberU64(), h.GasLimit(), h.GasUsed(),
		h.Time(), hexutil.Encode(h.Extra()), hexutil.Encode(h.MixDigest().Bytes()[:]), h.Nonce(), hexutil.Encode(h.Root().Bytes()[:]), h.BaseFee().Int64())

	m, _ := h.Bloom().MarshalText()
	log.Infof("logsBloom: %v", string(m))

	return encoding.BlockToBlockHeader(h), nil
}
