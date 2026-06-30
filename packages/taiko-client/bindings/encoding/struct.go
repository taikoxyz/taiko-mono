package encoding

import "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"

var GoldenTouchPrivKey = "92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"

// SubProofShasta should be same with Shasta ComposeVerifier.SubProof.
type SubProofShasta struct {
	VerifierId uint8
	Proof      []byte
}

// LastSeenProposal wraps a proposal metadata object with extra sync state.
type LastSeenProposal struct {
	metadata.TaikoProposalMetaData
	PreconfChainReorged bool
	LastBlockID         uint64
}
