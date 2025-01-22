package encoding

import (
	"crypto/rand"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

var (
	testHeader = &types.Header{
		ParentHash:  randomHash(),
		UncleHash:   types.EmptyUncleHash,
		Coinbase:    common.BytesToAddress(randomHash().Bytes()),
		Root:        randomHash(),
		TxHash:      randomHash(),
		ReceiptHash: randomHash(),
		Bloom:       types.BytesToBloom(randomHash().Bytes()),
		Difficulty:  new(big.Int).SetUint64(utils.RandUint64(nil)),
		Number:      new(big.Int).SetUint64(utils.RandUint64(nil)),
		GasLimit:    utils.RandUint64(nil),
		GasUsed:     utils.RandUint64(nil),
		Time:        uint64(time.Now().Unix()),
		Extra:       randomHash().Bytes(),
		MixDigest:   randomHash(),
		Nonce:       types.EncodeNonce(utils.RandUint64(nil)),
		BaseFee:     new(big.Int).SetUint64(utils.RandUint64(nil)),
	}
)

func TestToExecutableData(t *testing.T) {
	data := ToExecutableData(testHeader)
	require.Equal(t, testHeader.ParentHash, data.ParentHash)
	require.Equal(t, testHeader.Coinbase, data.FeeRecipient)
	require.Equal(t, testHeader.Root, data.StateRoot)
	require.Equal(t, testHeader.ReceiptHash, data.ReceiptsRoot)
	require.Equal(t, testHeader.Bloom.Bytes(), data.LogsBloom)
	require.Equal(t, testHeader.MixDigest, data.Random)
	require.Equal(t, testHeader.Number.Uint64(), data.Number)
	require.Equal(t, testHeader.GasLimit, data.GasLimit)
	require.Equal(t, testHeader.GasUsed, data.GasUsed)
	require.Equal(t, testHeader.Time, data.Timestamp)
	require.Equal(t, testHeader.Extra, data.ExtraData)
	require.Equal(t, testHeader.BaseFee, data.BaseFeePerGas)
	require.Equal(t, testHeader.Hash(), data.BlockHash)
	require.Equal(t, testHeader.TxHash, data.TxHash)
}

// randomHash generates a random blob of data and returns it as a hash.
func randomHash() common.Hash {
	var hash common.Hash
	if n, err := rand.Read(hash[:]); n != common.HashLength || err != nil {
		panic(err)
	}
	return hash
}

// randomBytes generates a random bytes.
func randomBytes(size int) (b []byte) {
	b = make([]byte, size)
	if _, err := rand.Read(b); err != nil {
		log.Crit("Generate random bytes error", "error", err)
	}
	return
}
