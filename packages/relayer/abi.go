package relayer

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

type BlockHeader struct {
	ParentHash       common.Hash    `abi:"parentHash"`
	OmmersHash       common.Hash    `abi:"ommersHash"`
	Beneficiary      common.Address `abi:"beneficiary"`
	StateRoot        common.Hash    `abi:"stateRoot"`
	TransactionsRoot common.Hash    `abi:"transactionsRoot"`
	ReceiptsRoot     common.Hash    `abi:"receiptsRoot"`
	Difficulty       *big.Int       `abi:"difficulty"`
	Height           *big.Int       `abi:"height"`
	GasLimit         uint64         `abi:"gasLimit"`
	GasUsed          uint64         `abi:"gasUsed"`
	Timestamp        uint64         `abi:"timestamp"`
	ExtraData        []byte         `abi:"extraData"`
	LogsBloom        [8][32]byte    `abi:"logsBloom"`
	MixHash          common.Hash    `abi:"mixHash"`
	Nonce            uint64         `abi:"nonce"`
}

type SignalProof struct {
	Header BlockHeader
	Proof  []byte
}

func LogsBloomToBytes(logsBloom types.Bloom) [8][32]byte {
	var ret = [8][32]byte{}
	bloom := [256]byte(logsBloom)
	fmt.Println("bloom", common.Bytes2Hex(bloom[:]))
	index := 0
	for i := 0; i < 256; i += 32 {
		end := i + 31
		b := bloom[i:end]
		var r [32]byte
		copy(r[:], b)
		ret[index] = r
		fmt.Println(common.Bytes2Hex(ret[index][:]))
		index++
	}
	return ret
}
