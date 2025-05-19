package encoding

import (
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

var GoldenTouchPrivKey = "92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"

// BlobParams should be same with ITaikoInbox.BlobParams.
type BlobParams struct {
	BlobHashes     [][32]byte
	FirstBlobIndex uint8
	NumBlobs       uint8
	ByteOffset     uint32
	ByteSize       uint32
	CreatedIn      uint64
}

// BatchParamsPacaya should be same with ITaikoInbox.BatchParams for Pacaya fork.
type BatchParamsPacaya struct {
	Proposer                 common.Address
	Coinbase                 common.Address
	ParentMetaHash           [32]byte
	AnchorBlockId            uint64
	LastBlockTimestamp       uint64
	RevertIfNotFirstProposal bool
	BlobParams               BlobParams
	Blocks                   []pacayaBindings.ITaikoInboxBlockParams
}

// BatchParamsShasta should be same with ITaikoInbox.BatchParams.
type BatchParamsShasta struct {
	Proposer                 common.Address
	Coinbase                 common.Address
	ParentMetaHash           [32]byte
	AnchorBlockId            uint64
	LastBlockTimestamp       uint64
	RevertIfNotFirstProposal bool
	BlobParams               BlobParams
	Blocks                   []shastaBindings.ITaikoInboxBlockParams
	ProverAuth               []byte
}

// SubProof should be same with ComposeVerifier.SubProof.
type SubProof struct {
	Verifier common.Address
	Proof    []byte
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

// LastSeenProposal is a wrapper for pacayaBindings.TaikoInboxClientBatchProposed,
// which contains additional information about the proposal.
type LastSeenProposal struct {
	metadata.TaikoProposalMetaData
	PreconfChainReorged bool
}

// BytesToBloom converts a [8][32]byte slice to types.Bloom.
func BytesToBloom(b [8][32]byte) types.Bloom {
	bytes := []byte{}

	for i := 0; i < 8; i++ {
		bytes = append(bytes, b[i][:]...)
	}

	return types.BytesToBloom(bytes)
}
