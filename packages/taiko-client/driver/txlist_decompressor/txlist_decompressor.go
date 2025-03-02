package txlistdecompressor

import (
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// TxListDecompressor is responsible for validating and decompressing
// the transactions list in a TaikoL1.proposeBlock transaction.
type TxListDecompressor struct {
	blockMaxGasLimit  uint64
	maxBytesPerTxList uint64
	chainID           *big.Int
}

// NewTxListDecompressor creates a new TxListDecompressor instance based on giving configurations.
func NewTxListDecompressor(
	blockMaxGasLimit uint64,
	maxBytesPerTxList uint64,
	chainID *big.Int,
) *TxListDecompressor {
	return &TxListDecompressor{
		blockMaxGasLimit:  blockMaxGasLimit,
		maxBytesPerTxList: maxBytesPerTxList,
		chainID:           chainID,
	}
}

// TryDecompress validates and decompresses whether the transactions list in the TaikoL1.proposeBlock transaction's
// input data is valid, the rules are:
// - If the transaction list is empty, it's valid.
// - If the transaction list is not empty:
//  1. If the transaction list is using calldata, the compressed bytes of the transaction list must be
//     less than or equal to maxBytesPerTxList.
//  2. The transaction list bytes must be able to be RLP decoded into a list of transactions.
func (v *TxListDecompressor) TryDecompress(
	chainID *big.Int,
	txListBytes []byte,
	blobUsed bool,
	postPacaya bool,
) types.Transactions {
	if chainID.Cmp(params.HeklaNetworkID) != 0 && !postPacaya {
		return v.tryDecompressHekla(txListBytes, blobUsed)
	}

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

// TryDecompressHekla is the same as tryDecompress, but it's used for Hekla network with
// an incorrect legacy bytes size check.
// ref: https://github.com/taikoxyz/taiko-client/pull/783
func (v *TxListDecompressor) tryDecompressHekla(
	txListBytes []byte,
	blobUsed bool,
) types.Transactions {
	// If the transaction list is empty, it's valid.
	if len(txListBytes) == 0 {
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

	// If calldata is used, the compressed bytes of the transaction list must be
	// less than or equal to maxBytesPerTxList.
	if !blobUsed && (len(txListBytes) > int(v.maxBytesPerTxList)) {
		log.Info("Compressed transactions list binary too large", "length", len(txListBytes))
		return types.Transactions{}
	}

	// Try to RLP decode the transaction list bytes.
	if err = rlp.DecodeBytes(txListBytes, &txs); err != nil {
		log.Info("Failed to decode transactions list bytes", "error", err)
		return types.Transactions{}
	}

	log.Info("Transaction list is valid")
	return txs
}
