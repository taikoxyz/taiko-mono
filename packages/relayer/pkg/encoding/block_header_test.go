package encoding

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"gopkg.in/go-playground/assert.v1"
)

func Test_BlockToBlockHeader_Legacy(t *testing.T) {
	header := &types.Header{
		ParentHash:  common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		UncleHash:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Coinbase:    common.HexToAddress("0x0000000000000000000000000000000000000000"),
		Root:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TxHash:      common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptHash: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Bloom:       types.Bloom{},
		Difficulty:  new(big.Int).SetInt64(2),
		Number:      new(big.Int).SetInt64(1),
		GasLimit:    100000,
		GasUsed:     2000,
		Time:        1234,
		Extra:       []byte{0x7f},
		MixDigest:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:       types.BlockNonce{0x13},
	}
	b := types.NewBlockWithHeader(header)

	h := BlockToBlockHeader(b)

	e := BlockHeader{
		ParentHash:       common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		OmmersHash:       common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Beneficiary:      common.HexToAddress("0x0000000000000000000000000000000000000000"),
		StateRoot:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TransactionsRoot: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptsRoot:     common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		LogsBloom:        [8][32]byte{},
		Difficulty:       new(big.Int).SetInt64(2),
		Height:           new(big.Int).SetInt64(1),
		GasLimit:         100000,
		GasUsed:          2000,
		Timestamp:        1234,
		ExtraData:        []byte{0x7f},
		MixHash:          common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:            1369094286720630784,
		BaseFeePerGas:    common.Big0,
	}

	assert.Equal(t, e, h)
}

func Test_BlockToBlockHeader_EIP1159(t *testing.T) {
	header := &types.Header{
		ParentHash:  common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		UncleHash:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Coinbase:    common.HexToAddress("0x0000000000000000000000000000000000000000"),
		Root:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TxHash:      common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptHash: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Bloom:       types.Bloom{},
		Difficulty:  new(big.Int).SetInt64(2),
		Number:      new(big.Int).SetInt64(1),
		GasLimit:    100000,
		GasUsed:     2000,
		Time:        1234,
		Extra:       []byte{0x7f},
		MixDigest:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:       types.BlockNonce{0x13},
		BaseFee:     big.NewInt(10),
	}
	b := types.NewBlockWithHeader(header)

	h := BlockToBlockHeader(b)

	e := BlockHeader{
		ParentHash:       common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		OmmersHash:       common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Beneficiary:      common.HexToAddress("0x0000000000000000000000000000000000000000"),
		StateRoot:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TransactionsRoot: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptsRoot:     common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		LogsBloom:        [8][32]byte{},
		Difficulty:       new(big.Int).SetInt64(2),
		Height:           new(big.Int).SetInt64(1),
		GasLimit:         100000,
		GasUsed:          2000,
		Timestamp:        1234,
		ExtraData:        []byte{0x7f},
		MixHash:          common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:            1369094286720630784,
		BaseFeePerGas:    big.NewInt(10),
	}

	assert.Equal(t, e, h)
}

func Test_BlockToBlockHeader_Shanghai(t *testing.T) {
	wRoot := common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347")

	header := &types.Header{
		ParentHash:      common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		UncleHash:       common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Coinbase:        common.HexToAddress("0x0000000000000000000000000000000000000000"),
		Root:            common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TxHash:          common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptHash:     common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Bloom:           types.Bloom{},
		Difficulty:      new(big.Int).SetInt64(2),
		Number:          new(big.Int).SetInt64(1),
		GasLimit:        100000,
		GasUsed:         2000,
		Time:            1234,
		Extra:           []byte{0x7f},
		MixDigest:       common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:           types.BlockNonce{0x13},
		BaseFee:         big.NewInt(10),
		WithdrawalsHash: &wRoot,
	}
	b := types.NewBlockWithHeader(header)

	h := BlockToBlockHeader(b)

	e := BlockHeader{
		ParentHash:       common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		OmmersHash:       common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Beneficiary:      common.HexToAddress("0x0000000000000000000000000000000000000000"),
		StateRoot:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TransactionsRoot: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptsRoot:     common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		LogsBloom:        [8][32]byte{},
		Difficulty:       new(big.Int).SetInt64(2),
		Height:           new(big.Int).SetInt64(1),
		GasLimit:         100000,
		GasUsed:          2000,
		Timestamp:        1234,
		ExtraData:        []byte{0x7f},
		MixHash:          common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:            1369094286720630784,
		BaseFeePerGas:    big.NewInt(10),
		WithdrawalsRoot:  wRoot,
	}

	assert.Equal(t, e, h)
}
