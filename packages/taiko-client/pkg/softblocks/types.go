package softblocks

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
)

// TransactionBatchMarker represents the status of a soft block transactions group.
type TransactionBatchMarker string

// BatchMarker valid values.
const (
	BatchMarkerEmpty TransactionBatchMarker = ""
	BatchMarkerEOB   TransactionBatchMarker = "endOfBlock"
	BatchMarkerEOP   TransactionBatchMarker = "endOfPreconf"
)

// SoftBlockParams represents the parameters for building a soft block.
type SoftBlockParams struct {
	// @param timestamp uint64 Timestamp of the soft block
	Timestamp uint64 `json:"timestamp"`
	// @param coinbase string Coinbase of the soft block
	Coinbase common.Address `json:"coinbase"`

	// @param anchorBlockID uint64 `_anchorBlockId` parameter of the `anchorV2` transaction in soft block
	AnchorBlockID uint64 `json:"anchorBlockID"`
	// @param anchorStateRoot string `_anchorStateRoot` parameter of the `anchorV2` transaction in soft block
	AnchorStateRoot common.Hash `json:"anchorStateRoot"`
}

// TransactionBatch represents a soft block group.
type TransactionBatch struct {
	// @param blockId uint64 Block ID of the soft block
	BlockID uint64 `json:"blockId"`
	// @param batchId uint64 ID of this transaction batch
	ID uint64 `json:"batchId"`
	// @param transactions string zlib compressed RLP encoded bytes of a transactions list
	TransactionsList []byte `json:"transactions"`
	// @param batchType TransactionBatchMarker Marker of the transaction batch,
	// @param either `end_of_block`, `end_of_preconf` or empty
	BatchMarker TransactionBatchMarker `json:"batchType"`
	// @param signature string Signature of this transaction batch
	Signature string `json:"signature" rlp:"-"`
	// @param blockParams SoftBlockParams Block parameters of the soft block
	BlockParams *SoftBlockParams `json:"blockParams"`
}

// ValidateSignature validates the signature of the transaction batch.
func (b *TransactionBatch) ValidateSignature() (bool, error) {
	payload, err := rlp.EncodeToBytes(b)
	if err != nil {
		return false, err
	}

	pubKey, err := crypto.SigToPub(crypto.Keccak256(payload), common.FromHex(b.Signature))
	if err != nil {
		return false, err
	}

	return crypto.PubkeyToAddress(*pubKey).Hex() == b.BlockParams.Coinbase.Hex(), nil
}
