package txlistvalidator

import (
	"crypto/rand"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/require"
)

var (
	maxBlocksGasLimit = uint64(50)
	maxBlockNumTxs    = uint64(11)
	maxTxlistBytes    = uint64(10000)
	chainID           = genesis.Config.ChainID
	testKey, _        = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
	testAddr          = crypto.PubkeyToAddress(testKey.PublicKey)
	genesis           = &core.Genesis{
		Config:    params.AllEthashProtocolChanges,
		Alloc:     types.GenesisAlloc{testAddr: {Balance: big.NewInt(2e15)}},
		ExtraData: []byte("test genesis"),
		Timestamp: 9000,
		BaseFee:   big.NewInt(params.InitialBaseFee),
	}
)

func TestIsTxListValid(t *testing.T) {
	v := NewTxListValidator(
		maxBlocksGasLimit,
		maxBlockNumTxs,
		maxTxlistBytes,
		chainID,
	)
	tests := []struct {
		name        string
		blockID     *big.Int
		txListBytes []byte
		wantReason  InvalidTxListReason
		wantTxIdx   int
	}{
		{
			"txListBytes binary too large",
			chainID,
			randBytes(maxTxlistBytes + 1),
			HintNone,
			0,
		},
		{
			"txListBytes not decodable to rlp",
			chainID,
			randBytes(0),
			HintNone,
			0,
		},
		{
			"txListBytes too many transactions",
			chainID,
			rlpEncodedTransactionBytes(int(maxBlockNumTxs)+1, true),
			HintNone,
			0,
		},
		{
			"success empty tx list",
			chainID,
			rlpEncodedTransactionBytes(0, true),
			HintOK,
			0,
		},
		{
			"success non-empty tx list",
			chainID,
			rlpEncodedTransactionBytes(1, true),
			HintOK,
			0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reason, txIdx := v.isTxListValid(tt.blockID, tt.txListBytes, false)
			require.Equal(t, tt.wantReason, reason)
			require.Equal(t, tt.wantTxIdx, txIdx)
		})
	}
}

func rlpEncodedTransactionBytes(l int, signed bool) []byte {
	txs := make(types.Transactions, 0)
	for i := 0; i < l; i++ {
		var tx *types.Transaction
		if signed {
			txData := &types.LegacyTx{
				Nonce:    1,
				To:       &testAddr,
				GasPrice: common.Big256,
				Value:    common.Big1,
				Gas:      10,
			}

			tx = types.MustSignNewTx(testKey, types.LatestSigner(genesis.Config), txData)
		} else {
			tx = types.NewTransaction(1, testAddr, common.Big1, 10, common.Big256, nil)
		}
		txs = append(
			txs,
			tx,
		)
	}
	b, _ := rlp.EncodeToBytes(txs)
	return b
}

func randBytes(l uint64) []byte {
	b := make([]byte, l)
	if _, err := rand.Read(b); err != nil {
		log.Crit("Failed to generate random bytes", "error", err)
	}
	return b
}
