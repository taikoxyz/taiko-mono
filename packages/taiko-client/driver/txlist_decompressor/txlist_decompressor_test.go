package txlistdecompressor

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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
)

var (
	maxBlocksGasLimit = uint64(50)
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

func TestDecomporess(t *testing.T) {
	d := NewTxListDecompressor(
		maxBlocksGasLimit,
		maxTxlistBytes,
		chainID,
	)
	compressed, err := utils.Compress(rlpEncodedTransactionBytes(1, true))
	require.NoError(t, err)

	tests := []struct {
		name         string
		blockID      *big.Int
		txListBytes  []byte
		decompressed []byte
	}{
		{
			"txListBytes binary too large",
			chainID,
			randBytes(maxTxlistBytes + 1),
			[]byte{},
		},
		{
			"txListBytes not decodable to rlp",
			chainID,
			randBytes(0x1),
			[]byte{},
		},
		{
			"success empty tx list",
			chainID,
			rlpEncodedTransactionBytes(0, true),
			[]byte{},
		},
		{
			"success non-empty tx list",
			chainID,
			compressed,
			rlpEncodedTransactionBytes(1, true),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			require.Equal(t, tt.decompressed, d.TryDecompress(tt.blockID, tt.txListBytes, false))
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
			tx = types.NewTransaction(1, testAddr, common.Big1, 10, new(big.Int).SetUint64(10*params.GWei), nil)
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
