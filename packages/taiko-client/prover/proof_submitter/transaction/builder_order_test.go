package transaction

import (
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func TestOrderedSubProofsAscendingVerifierIDs(t *testing.T) {
	// Default mode: SGX_GETH companion (1) + ZK primary (5/6), already ascending.
	require.Equal(t, []encoding.SubProofShasta{
		{VerifierId: 1, Proof: []byte{0x01}},
		{VerifierId: 6, Proof: []byte{0x06}},
	}, orderedSubProofs(&producer.BatchProofs{
		CompanionVerifierID: 1,
		CompanionBatchProof: []byte{0x01},
		VerifierID:          6,
		BatchProof:          []byte{0x06},
	}))

	// ZK-only mode: RISC0 companion (5) + SP1 primary (6), already ascending.
	require.Equal(t, []encoding.SubProofShasta{
		{VerifierId: 5, Proof: []byte{0x05}},
		{VerifierId: 6, Proof: []byte{0x06}},
	}, orderedSubProofs(&producer.BatchProofs{
		CompanionVerifierID: 5,
		CompanionBatchProof: []byte{0x05},
		VerifierID:          6,
		BatchProof:          []byte{0x06},
	}))

	// A companion with a higher verifier ID than the primary proof must be swapped, since
	// ComposeVerifier rejects sub-proofs in descending verifier ID order.
	require.Equal(t, []encoding.SubProofShasta{
		{VerifierId: 5, Proof: []byte{0x05}},
		{VerifierId: 6, Proof: []byte{0x06}},
	}, orderedSubProofs(&producer.BatchProofs{
		CompanionVerifierID: 6,
		CompanionBatchProof: []byte{0x06},
		VerifierID:          5,
		BatchProof:          []byte{0x05},
	}))
}
