package builder

import (
	"context"
	"encoding/hex"
	"strings"

	"github.com/ethereum/go-ethereum/core/types"

	"github.com/ethereum/go-ethereum/rlp"
)

type BuildUnsignedOpts struct {
	MultipleBlobs bool
	BlockOpts     []BlockOpts
}
type BlockOpts struct {
	L1StateBlockNumber uint32
	Timestamp          uint64
	SignedTransactions []string
	Coinbase           string
	ExtraData          string
}
type TxBuilder interface {
	BuildUnsigned(
		ctx context.Context,
		opts BuildUnsignedOpts,
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
