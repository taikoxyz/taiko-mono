package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

var GoldenTouchPrivKey = "92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"

// LibProofType.ProofType constants
const (
	ProofTypeEmpty     uint16 = 0x00 // 0b0000
	ProofTypeSgxReth   uint16 = 0x01 // 0b0001
	ProofTypeTdxReth   uint16 = 0x02 // 0b0010
	ProofTypeRisc0Reth uint16 = 0x04 // 0b0100
	ProofTypeSp1Reth   uint16 = 0x08 // 0b1000
	ProofTypeSgxGeth   uint16 = 0x10 // 0b10000
)

// GetProofTypeFromString converts a producer.ProofType string to the corresponding LibProofType.ProofType constant
func GetProofTypeFromString(proofType string) uint16 {
	switch proofType {
	case "sgx":
		return ProofTypeSgxReth
	case "tdx":
		return ProofTypeTdxReth
	case "risc0":
		return ProofTypeRisc0Reth
	case "sp1":
		return ProofTypeSp1Reth
	case "sgxgeth":
		return ProofTypeSgxGeth
	default:
		return ProofTypeEmpty
	}
}

// BlobParams should be same with ITaikoInbox.BlobParams.
type BlobParams struct {
	BlobHashes     [][32]byte
	FirstBlobIndex uint8
	NumBlobs       uint8
	ByteOffset     uint32
	ByteSize       uint32
	CreatedIn      uint64
}

// BatchParams should be same with ITaikoInbox.BatchParams.
type BatchParams struct {
	Proposer                 common.Address
	Coinbase                 common.Address
	ParentMetaHash           [32]byte
	BaseFee                  *big.Int
	AnchorBlockId            uint64
	LastBlockTimestamp       uint64
	RevertIfNotFirstProposal bool
	BlobParams               BlobParams
	Blocks                   []pacayaBindings.ITaikoInboxBlockParams
}

// SubProof should be same as ISurgeVerifier.SubProof.
type SubProof struct {
	ProofType uint16
	Proof     []byte
}

// LastSeenProposal is a wrapper for pacayaBindings.TaikoInboxClientBatchProposed,
// which contains additional information about the proposal.
type LastSeenProposal struct {
	metadata.TaikoProposalMetaData
	PreconfChainReorged bool
}

// ToExecutableData converts a GETH *types.Header to *engine.ExecutableData.
func ToExecutableData(header *types.Header) *engine.ExecutableData {
	executableData := &engine.ExecutableData{
		ParentHash:    header.ParentHash,
		FeeRecipient:  header.Coinbase,
		StateRoot:     header.Root,
		ReceiptsRoot:  header.ReceiptHash,
		LogsBloom:     header.Bloom.Bytes(),
		Random:        header.MixDigest,
		Number:        header.Number.Uint64(),
		GasLimit:      header.GasLimit,
		GasUsed:       header.GasUsed,
		Timestamp:     header.Time,
		ExtraData:     header.Extra,
		BaseFeePerGas: header.BaseFee,
		BlockHash:     header.Hash(),
		TxHash:        header.TxHash,
	}

	if header.WithdrawalsHash != nil {
		executableData.WithdrawalsHash = *header.WithdrawalsHash
	}

	return executableData
}
