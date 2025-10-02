package blocksinserter

import (
	"context"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// Inserter is an interface that defines the method to insert blocks to the L2 execution engine.
type Inserter interface {
	InsertBlocks(
		ctx context.Context,
		metadata metadata.TaikoProposalMetaData,
		endIter eventIterator.EndBatchProposedEventIterFunc,
	) error
	InsertBlocksWithManifest(
		ctx context.Context,
		metadata metadata.TaikoProposalMetaData,
		proposalManifest *manifest.ProposalManifest,
		endIter eventIterator.EndBatchProposedEventIterFunc,
	) error
}

// createExecutionPayloadsMetaData is a struct that contains all the necessary metadata
// for creating a new execution payloads.
type createExecutionPayloadsMetaData struct {
	BlockID               *big.Int
	BatchID               *big.Int
	ExtraData             []byte
	SuggestedFeeRecipient common.Address
	GasLimit              uint64
	Difficulty            common.Hash
	Timestamp             uint64
	ParentHash            common.Hash
	L1Origin              *rawdb.L1Origin
	Txs                   types.Transactions
	BaseFee               *big.Int
	Withdrawals           []*types.Withdrawal
}

// createPayloadAndSetHeadMetaData is a struct that contains all the necessary metadata
// for inserting a new head block to the L2 execution engine's local block chain.
type createPayloadAndSetHeadMetaData struct {
	*createExecutionPayloadsMetaData
	Parent *types.Header
}
