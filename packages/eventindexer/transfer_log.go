package eventindexer

// Kinds of transfer log whose application is tracked in processed_transfer_logs.
const (
	TransferKindNFT   = "nft"
	TransferKindERC20 = "erc20"
)

// TransferLogRef uniquely identifies a single balance-mutating unit of a transfer
// log. An ERC20 Transfer, an ERC721 Transfer, and an ERC1155 TransferSingle each
// produce one unit with BatchIndex 0; an ERC1155 TransferBatch produces one unit
// per token id, indexed by its position in the batch.
type TransferLogRef struct {
	ChainID    int64
	TxHash     string
	LogIndex   uint
	BatchIndex uint
	Kind       string
}

// ProcessedTransferLog records that a transfer log's balance mutation has already
// been applied.
//
// The indexer deliberately re-processes a trailing range of blocks on every
// restart: setInitialIndexingBlockByMode rewinds the cursor to
// MAX(events.emitted_block_id) - 1 and filter() resumes at cursor + 1. Balances
// are maintained by read-modify-write, so without this record a replayed transfer
// increments the recipient a second time while the sender's row is already gone,
// silently and permanently corrupting the balance.
type ProcessedTransferLog struct {
	ID         int64  `json:"id"`
	ChainID    int64  `json:"chainID"`
	TxHash     string `json:"txHash"`
	LogIndex   uint   `json:"logIndex"`
	BatchIndex uint   `json:"batchIndex"`
	Kind       string `json:"kind"`
}
