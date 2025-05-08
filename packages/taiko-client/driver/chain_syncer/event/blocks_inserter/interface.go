package blocksinserter

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// Inserter is an interface that defines the method to insert blocks to the L2 execution engine.
type Inserter interface {
	InsertBlocks(
		ctx context.Context,
		metadata metadata.TaikoProposalMetaData,
		endIter eventIterator.EndBlockProposedEventIterFunc,
	) error
}

// createExecutionPayloadsMetaData is a struct that contains all the necessary metadata
// for creating a new execution payloads.
type createExecutionPayloadsMetaData struct {
	BlockID               *big.Int
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
	AnchorBlockID   *big.Int
	AnchorBlockHash common.Hash
	BaseFeeConfig   *pacayaBindings.LibSharedDataBaseFeeConfig
	Parent          *types.Header
}
