package encoding

import (
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
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

// BatchParams should be same with ITaikoInbox.BatchParams.
type BatchParams struct {
	Proposer                 common.Address
	Coinbase                 common.Address
	ParentMetaHash           [32]byte
	AnchorBlockId            uint64
	LastBlockTimestamp       uint64
	RevertIfNotFirstProposal bool
	BlobParams               BlobParams
	Blocks                   []pacayaBindings.ITaikoInboxBlockParams
}

// SubProof should be same with ComposeVerifier.SubProof.
type SubProof struct {
	Verifier common.Address
	Proof    []byte
}

// LastSeenProposal is a wrapper for pacayaBindings.TaikoInboxClientBatchProposed,
// which contains additional information about the proposal.
type LastSeenProposal struct {
	metadata.TaikoProposalMetaData
	PreconfChainReorged bool
}
