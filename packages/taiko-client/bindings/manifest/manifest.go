package manifest

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/params"
)

const (
	// ProposalMaxBlobs The maximum number of blobs allowed in a proposal, refer to LibManifest.PROPOSAL_MAX_BLOBS.
	ProposalMaxBlobs   = 4
	ValidShastaVersion = 0x1
	BlobBytes          = params.BlobTxBytesPerFieldElement * params.BlobTxFieldElementsPerBlob
	// ProposalMaxBytes The maximum number of bytes allowed in a proposal, refer to LibManifest.PROPOSAL_MAX_BLOBS.
	ProposalMaxBytes = BlobBytes * ProposalMaxBlobs
	// ProposalMaxBlocks The maximum number of blocks allowed in a proposal, refer to LibManifest.PROPOSAL_MAX_BLOCKS.
	ProposalMaxBlocks = 384
	// BlockMaxRawTransactions Maximum number of transactions allowed in proposal's manifest data, refer to LibManifest.BLOCK_MAX_RAW_TRANSACTIONS.
	BlockMaxRawTransactions = 4096 * 2
)

// SignedTransaction represents a signed Ethereum transaction
// Follows EIP-2718 typed transaction format with EIP-1559 support
// Should be same with LibManifest.SignedTransaction
type SignedTransaction struct {
	TxType               uint8          `json:"txType"`
	ChainId              uint64         `json:"chainId"`
	Nonce                uint64         `json:"nonce"`
	MaxPriorityFeePerGas *big.Int       `json:"maxPriorityFeePerGas"`
	MaxFeePerGas         *big.Int       `json:"maxFeePerGas"`
	GasLimit             uint64         `json:"gasLimit"`
	To                   common.Address `json:"to"`
	Value                *big.Int       `json:"value"`
	Data                 []byte         `json:"data"`
	AccessList           []byte         `json:"accessList"`
	V                    uint8          `json:"v"`
	R                    common.Hash    `json:"r"`
	S                    common.Hash    `json:"s"`
}

// BlockManifest represents a block manifest
// Should be same with LibManifest.BlockManifest
type BlockManifest struct {
	// The timestamp of the block
	Timestamp uint64 `json:"timestamp"`
	// The coinbase of the block
	Coinbase common.Address `json:"coinbase"`
	// The anchor block number. This field can be zero, if so, this block will use the
	// most recent anchor in a previous block
	AnchorBlockNumber uint64 `json:"anchorBlockNumber"`
	// The block's gas limit
	GasLimit uint64 `json:"gasLimit"`
	// The transactions for this block
	Transactions []SignedTransaction `json:"transactions"`
}

// ProposalManifest represents a proposal manifest
// Should be same with LibManifest.ProposalManifest
type ProposalManifest struct {
	ProverAuthBytes []byte          `json:"proverAuthBytes"`
	Blocks          []BlockManifest `json:"blocks"`
}
