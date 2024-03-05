package db

import (
	"bytes"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
)

func Test_BuildBlockKey(t *testing.T) {
	assert.Equal(t, []byte("block++1++300"), BuildBlockKey(1, 300))
}

func Test_BuildBlockValue(t *testing.T) {
	v := BuildBlockValue([]byte("hash"), []byte("sig"), big.NewInt(1))
	spl := bytes.Split(v, []byte(separator))
	assert.Equal(t, "hash", string(spl[0]))
	assert.Equal(t, "sig", string(spl[1]))
	assert.Equal(t, uint64(1), new(big.Int).SetBytes(spl[2]).Uint64())
}

func Test_SignedBlockDataFromValue(t *testing.T) {
	hash := common.HexToHash("1ada5c5ba58cfca1fbcd4531f4132f8cfef736c2cf40209a1315c489717dfc49")
	// nolint: lll
	sig := common.Hex2Bytes("789a80053e4927d0a898db8e065e948f5cf086e32f9ccaa54c1908e22ac430c62621578113ddbb62d509bf6049b8fb544ab06d36f916685a2eb8e57ffadde02301")

	v := BuildBlockValue(hash.Bytes(), sig, big.NewInt(1))
	data := SignedBlockDataFromValue(v)

	assert.Equal(t, common.Bytes2Hex(sig), data.Signature)
	assert.Equal(t, hash, data.BlockHash)
	assert.Equal(t, data.BlockID, big.NewInt(1))
}
