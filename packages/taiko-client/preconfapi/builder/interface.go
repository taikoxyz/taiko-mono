package builder

import (
	"context"
	"encoding/hex"
	"strings"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"
)

type BuildBlocksUnsignedOpts struct {
	BlockOpts        []BuildBlockUnsignedOpts
	PreconferAddress string
}
type BuildBlockUnsignedOpts struct {
	L1StateBlockNumber uint32
	Timestamp          uint64
	SignedTransactions []string
	Coinbase           string
	PreconferAddress   string
}

type TxBuilder interface {
	BuildBlockUnsigned(
		ctx context.Context,
		opts BuildBlockUnsignedOpts,
	) (*types.Transaction, error)
	BuildBlocksUnsigned(
		ctx context.Context,
		opts BuildBlocksUnsignedOpts,
	) (*types.Transaction, error)
}

func signedTransactionsToTxListBytes(txs []string) ([]byte, error) {
	var transactions types.Transactions

	for _, signedTxHex := range txs {
		signedTxHex = strings.TrimPrefix(signedTxHex, "0x")

		rlpEncodedBytes, err := hex.DecodeString(signedTxHex)
		if err != nil {
			return nil, err
		}

		var tx types.Transaction
		if err := rlp.DecodeBytes(rlpEncodedBytes, &tx); err != nil {
			return nil, err
		}

		transactions = append(transactions, &tx)
	}

	txListBytes, err := rlp.EncodeToBytes(transactions)
	if err != nil {
		return nil, err
	}

	return txListBytes, nil
}
