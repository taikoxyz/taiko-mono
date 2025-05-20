package params

import (
	"github.com/ethereum/go-ethereum/common"
)

// BatchParamsPacaya should be same with ITaikoInbox.BatchParams for Pacaya protocol.
type BatchParamsPacaya struct {
	proposer                 common.Address
	coinbase                 common.Address
	parentMetaHash           [32]byte
	anchorBlockId            uint64
	lastBlockTimestamp       uint64
	revertIfNotFirstProposal bool
	blobParams               ITaikoInboxBlobParams
	blocks                   []ITaikoInboxBlockParams
}

// NewBatchParamsPacaya creates a new BatchParamsPacaya instance.
func NewBatchParamsPacaya(
	proposer common.Address,
	coinbase common.Address,
	parentMetaHash [32]byte,
	anchorBlockId uint64,
	lastBlockTimestamp uint64,
	revertIfNotFirstProposal bool,
	blobParams ITaikoInboxBlobParams,
	blocks []ITaikoInboxBlockParams,
) *BatchParamsPacaya {
	return &BatchParamsPacaya{
		proposer:                 proposer,
		coinbase:                 coinbase,
		parentMetaHash:           parentMetaHash,
		anchorBlockId:            anchorBlockId,
		lastBlockTimestamp:       lastBlockTimestamp,
		revertIfNotFirstProposal: revertIfNotFirstProposal,
		blobParams:               blobParams,
		blocks:                   blocks,
	}
}

// Proposer returns the address of the proposer.
func (p *BatchParamsPacaya) Proposer() common.Address {
	return p.proposer
}

// Proposer returns the fee recipient address.
func (p *BatchParamsPacaya) Coinbase() common.Address {
	return p.coinbase
}

// ParentMetaHash returns the parent meta hash.
func (p *BatchParamsPacaya) ParentMetaHash() [32]byte {
	return p.parentMetaHash
}

// AnchorBlockId returns the anchor block ID.
func (p *BatchParamsPacaya) AnchorBlockId() uint64 {
	return p.anchorBlockId
}

// LastBlockTimestamp returns the last block timestamp.
func (p *BatchParamsPacaya) LastBlockTimestamp() uint64 {
	return p.lastBlockTimestamp
}

// RevertIfNotFirstProposal returns whether to revert if not the first proposal.
func (p *BatchParamsPacaya) RevertIfNotFirstProposal() bool {
	return p.revertIfNotFirstProposal
}

// BlobParams returns the blob parameters.
func (p *BatchParamsPacaya) BlobParams() ITaikoInboxBlobParams {
	return p.blobParams
}

// Blocks returns the inner blocks.
func (p *BatchParamsPacaya) Blocks() []ITaikoInboxBlockParams {
	return p.blocks
}

// ProverAuth returns the prover authentication data, for Pacaya it is nil.
func (p *BatchParamsPacaya) ProverAuth() []byte {
	return nil
}

// IsShasta returns false for Pacaya protoocl.
func (p *BatchParamsPacaya) IsShasta() bool {
	return false
}
