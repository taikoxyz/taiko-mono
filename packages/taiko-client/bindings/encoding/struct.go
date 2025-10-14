package encoding

import (
	"math/big"

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
	VerifierId uint8
	Proof      []byte
}

// VerifierId enum should match ComposeVerifier.VerifierId
const (
	VerifierIdNone       uint8 = 0
	VerifierIdSgxGeth    uint8 = 1
	VerifierIdTdxGeth    uint8 = 2
	VerifierIdOp         uint8 = 3
	VerifierIdSgxReth    uint8 = 4
	VerifierIdRisc0Reth  uint8 = 5
	VerifierIdSp1Reth    uint8 = 6
)

// ProofTypeToVerifierId maps proof types to verifier IDs
func ProofTypeToVerifierId(proofType string) uint8 {
	switch proofType {
	case "sgxgeth", "sgx", "native":
		return VerifierIdSgxReth
	case "risc0":
		return VerifierIdRisc0Reth
	case "sp1":
		return VerifierIdSp1Reth
	case "op":
		return VerifierIdOp
	default:
		return VerifierIdNone
	}
}

// LastSeenProposal is a wrapper for pacayaBindings.TaikoInboxClientBatchProposed,
// which contains additional information about the proposal.
type LastSeenProposal struct {
	metadata.TaikoProposalMetaData
	PreconfChainReorged bool
}

// ProverAuth represents the prover authorization data structure in ShastaAnchor.
type ProverAuth struct {
	ProposalId     *big.Int
	Proposer       common.Address
	ProvingFeeGwei *big.Int
	Signature      []byte
}
