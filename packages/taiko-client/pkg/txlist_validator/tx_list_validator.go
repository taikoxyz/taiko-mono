package txlistvalidator

import (
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
)

// TxListValidator is responsible for validating the transactions list in a TaikoL1.proposeBlock transaction.
type TxListValidator struct {
	blockMaxGasLimit  uint64
	maxBytesPerTxList uint64
	chainID           *big.Int
}

// NewTxListValidator creates a new TxListValidator instance based on giving configurations.
func NewTxListValidator(
	blockMaxGasLimit uint64,
	maxBytesPerTxList uint64,
	chainID *big.Int,
) *TxListValidator {
	return &TxListValidator{
		blockMaxGasLimit:  blockMaxGasLimit,
		maxBytesPerTxList: maxBytesPerTxList,
		chainID:           chainID,
	}
}

// ValidateTxList checks whether the transactions list in the TaikoL1.proposeBlock transaction's
// input data is valid.
func (v *TxListValidator) ValidateTxList(
	blockID *big.Int,
	txListBytes []byte,
	blobUsed bool,
) (isValid bool) {
	// If the transaction list is empty, it's valid.
	if len(txListBytes) == 0 {
		return true
	}

	if !blobUsed && (len(txListBytes) > int(v.maxBytesPerTxList)) {
		log.Info("Transactions list binary too large", "length", len(txListBytes), "blockID", blockID)
		return false
	}

	var txs types.Transactions
	if err := rlp.DecodeBytes(txListBytes, &txs); err != nil {
		log.Info("Failed to decode transactions list bytes", "blockID", blockID, "error", err)
		return false
	}

	log.Info("Transaction list is valid", "blockID", blockID)
	return true
}
