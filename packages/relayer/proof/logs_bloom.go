package proof

import "github.com/ethereum/go-ethereum/core/types"

func logsBloomToBytes(logsBloom types.Bloom) ([8][32]byte, error) {
	var ret = [8][32]byte{}
	bloom := [256]byte(logsBloom)
	index := 0
	for i := 0; i < 256; i += 32 {
		end := i + 31
		b := bloom[i:end]
		var r [32]byte
		copy(r[:], b)
		ret[index] = r
		index++
	}
	return ret, nil
}
