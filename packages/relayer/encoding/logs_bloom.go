package encoding

import "github.com/ethereum/go-ethereum/core/types"

func logsBloomToBytes(bloom types.Bloom) [8][32]byte {
	b := [8][32]byte{}

	for i := 0; i < 8; i++ {
		copy(b[i][:], bloom[i*32:(i+1)*32])
	}

	return b
}
