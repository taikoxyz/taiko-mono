package txlistdecompressor

import (
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// TxListDecompressor is responsible for validating and decompressing
// the transactions list in a Pacaya TaikoInbox.proposeBatch transaction.
type TxListDecompressor struct {
	maxBytesPerTxList uint64
}

// NewTxListDecompressor creates a new TxListDecompressor instance based on giving configurations.
func NewTxListDecompressor(maxBytesPerTxList uint64) *TxListDecompressor {
	return &TxListDecompressor{maxBytesPerTxList: maxBytesPerTxList}
}

// TryDecompress validates and decompresses whether the transactions list in the
// Pacaya TaikoInbox.proposeBatch transaction's input data is valid, the rules are:
// - If the transaction list is empty, it's valid.
// - If the transaction list is not empty:
//  1. If the transaction list is using calldata, the compressed bytes of the transaction list must be
//     less than or equal to maxBytesPerTxList.
//  2. The transaction list bytes must be able to be RLP decoded into a list of transactions.
func (v *TxListDecompressor) TryDecompress(txListBytes []byte, blobUsed bool) types.Transactions {
	return v.tryDecompress(txListBytes, blobUsed)
}

// tryDecompress is the inner implementation of TryDecompress.
func (v *TxListDecompressor) tryDecompress(
	txListBytes []byte,
	blobUsed bool,
) types.Transactions {
	// If the transaction list is empty, it's valid.
	if len(txListBytes) == 0 {
		return types.Transactions{}
	}

	// If calldata is used, the compressed bytes of the transaction list must be
	// less than or equal to maxBytesPerTxList.
	if !blobUsed && (len(txListBytes) > int(v.maxBytesPerTxList)) {
		log.Info(
			"Compressed transactions list binary too large",
			"length", len(txListBytes),
		)
		return types.Transactions{}
	}

	var (
		txs types.Transactions
		err error
	)

	// Decompress the transaction list bytes.
	if txListBytes, err = utils.Decompress(txListBytes); err != nil {
		log.Info("Failed to decompress tx list bytes", "error", err)
		return types.Transactions{}
	}

	// Try to RLP decode the transaction list bytes.
	if err = rlp.DecodeBytes(txListBytes, &txs); err != nil {
		log.Info("Failed to decode transactions list bytes", "error", err)
		return types.Transactions{}
	}

	return txs
}
