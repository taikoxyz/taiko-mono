package indexer

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

// addressHexFromTopic returns the 0x-prefixed hex encoding of an indexed address topic.
// In Ethereum logs, indexed address values are right-aligned in a 32-byte topic, so the
// address bytes are the last 20 bytes.
func addressHexFromTopic(topic common.Hash) string {
	return hexutil.Encode(topic.Bytes()[12:])
}
