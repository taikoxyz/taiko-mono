package bindingTypes

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

var (
	_ ITaikoInboxBatchParams               = new(BatchParamsPacaya)
	_ ITaikoInboxBatchParams               = new(BatchParamsShasta)
	_ ITaikoInboxBlobParams                = new(BlobParams)
	_ ITaikoInboxBlockParams               = new(BlockParams)
	_ IForcedInclusionStoreForcedInclusion = new(ForcedInclusionPacaya)
	_ IForcedInclusionStoreForcedInclusion = new(ForcedInclusionShasta)
	_ ITaikoInboxStats                     = new(InboxStatsPacaya)
	_ ITaikoInboxStats                     = new(InboxStatsShasta)
	_ ITaikoInboxBatch                     = new(InboxBatchPacaya)
	_ ITaikoInboxBatch                     = new(InboxBatchShasta)
)

// ITaikoInboxBatchParams should be same with ITaikoInbox.BatchParams.
type ITaikoInboxBatchParams interface {
	Proposer() common.Address
	Coinbase() common.Address
	ParentMetaHash() [32]byte
	AnchorBlockId() uint64
	LastBlockTimestamp() uint64
	RevertIfNotFirstProposal() bool
	BlobParams() ITaikoInboxBlobParams
	Blocks() []ITaikoInboxBlockParams
	ProverAuth() []byte
	IsShasta() bool
}

// ITaikoInboxBlockParams should be same with ITaikoInbox.BlockParams.
type ITaikoInboxBlockParams interface {
	NumTransactions() uint16
	TimeShift() uint8
	SignalSlots() [][32]byte
}

// ITaikoInboxBlobParams should be same with ITaikoInbox.BlobParams.
type ITaikoInboxBlobParams interface {
	BlobHashes() [][32]byte
	FirstBlobIndex() uint8
	NumBlobs() uint8
	ByteOffset() uint32
	ByteSize() uint32
	CreatedIn() uint64
}

// IForcedInclusionStoreForcedInclusion should be same with IForcedInclusionStore.ForcedInclusion.
type IForcedInclusionStoreForcedInclusion interface {
	BlobHash() [32]byte
	FeeInGwei() uint64
	CreatedAtBatchId() uint64
	BlobByteOffset() uint32
	BlobByteSize() uint32
	BlobCreatedIn() uint64
}

// ITaikoInboxStats should be same with ITaikoInbox.Stats1 and ITaikoInbox.Stats2.
type ITaikoInboxStats interface {
	GenesisHeight() uint64
	LastSyncedBatchId() uint64
	LastSyncedAt() uint64
	NumBatches() uint64
	LastVerifiedBatchId() uint64
	Paused() bool
	LastProposedIn() uint64
	LastUnpausedAt() uint64
}

// ITaikoInboxBatch should be same with ITaikoInbox.Batch.
type ITaikoInboxBatch interface {
	MetaHash() common.Hash
	LastBlockID() uint64
	LivenessBond() *big.Int
	BatchId() uint64
	LastBlockTimestamp() uint64
	AnchorBlockId() uint64
	NextTransitionId() *big.Int
	VerifiedTransitionId() *big.Int
}

// LibSharedDataBaseFeeConfig should be same with LibSharedData.BaseFeeConfig.
type LibSharedDataBaseFeeConfig interface {
	AdjustmentQuotient() uint8
	GasIssuancePerSecond() uint32
	SharingPctgs() [2]uint8
	MinGasExcess() uint64
	MaxGasIssuancePerBlock() uint32
}
