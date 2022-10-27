package indexer

import "github.com/umbracle/ethgo/abi"

var (
	signalProofType  = abi.MustNewType("tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce) header, bytes proof)")
	storageProofType = abi.MustNewType("bytes")
)
