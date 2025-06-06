package encoding

import (
	"crypto/rand"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

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
