package params

import "github.com/ethereum/go-ethereum/common"

// BatchParamsShasta should be same with ITaikoInbox.BatchParams for Shasta protocol.
type BatchParamsShasta struct {
	proposer                 common.Address
	coinbase                 common.Address
	parentMetaHash           [32]byte
	anchorBlockId            uint64
	lastBlockTimestamp       uint64
	revertIfNotFirstProposal bool
	blobParams               ITaikoInboxBlobParams
	blocks                   []ITaikoInboxBlockParams
	proverAuth               []byte
}

// NewBatchParamsShasta creates a new BatchParamsShasta instance.
func NewBatchParamsShasta(
	proposer common.Address,
	coinbase common.Address,
	parentMetaHash [32]byte,
	anchorBlockId uint64,
	lastBlockTimestamp uint64,
	revertIfNotFirstProposal bool,
	blobParams ITaikoInboxBlobParams,
	blocks []ITaikoInboxBlockParams,
	proverAuth []byte,
) *BatchParamsShasta {
	return &BatchParamsShasta{
		proposer:                 proposer,
		coinbase:                 coinbase,
		parentMetaHash:           parentMetaHash,
		anchorBlockId:            anchorBlockId,
		lastBlockTimestamp:       lastBlockTimestamp,
		revertIfNotFirstProposal: revertIfNotFirstProposal,
		blobParams:               blobParams,
		blocks:                   blocks,
		proverAuth:               proverAuth,
	}
}

// Proposer returns the address of the proposer.
func (p *BatchParamsShasta) Proposer() common.Address {
	return p.proposer
}

// Proposer returns the fee recipient address.
func (p *BatchParamsShasta) Coinbase() common.Address {
	return p.coinbase
}

// ParentMetaHash returns the parent meta hash.
func (p *BatchParamsShasta) ParentMetaHash() [32]byte {
	return p.parentMetaHash
}

// AnchorBlockId returns the anchor block ID.
func (p *BatchParamsShasta) AnchorBlockId() uint64 {
	return p.anchorBlockId
}

// LastBlockTimestamp returns the last block timestamp.
func (p *BatchParamsShasta) LastBlockTimestamp() uint64 {
	return p.lastBlockTimestamp
}

// RevertIfNotFirstProposal returns whether to revert if not the first proposal.
func (p *BatchParamsShasta) RevertIfNotFirstProposal() bool {
	return p.revertIfNotFirstProposal
}

// BlobParams returns the blob parameters.
func (p *BatchParamsShasta) BlobParams() ITaikoInboxBlobParams {
	return p.blobParams
}

// Blocks returns the inner blocks.
func (p *BatchParamsShasta) Blocks() []ITaikoInboxBlockParams {
	return p.blocks
}

// ProverAuth returns the prover auth.
func (p *BatchParamsShasta) ProverAuth() []byte {
	return p.proverAuth
}

// IsShasta returns true for Shasta protocol.
func (p *BatchParamsShasta) IsShasta() bool {
	return true
}
