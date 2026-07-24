package prover

import (
	"testing"

	"github.com/stretchr/testify/require"

	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func (s *ProverTestSuite) TestInitUsesShastaSubmitterOnly() {
	s.NotNil(s.p.proofSubmitter)
}

func TestVerifierIDsByProofTypeUsesSGXRethVerifierID(t *testing.T) {
	require.Equal(t, uint8(4), verifierIDsByProofType()[producer.ProofTypeSgx])
}

func TestEnabledProofTypes(t *testing.T) {
	t.Run("default supports RISC0 and SP1", func(t *testing.T) {
		require.Equal(
			t,
			[]producer.ProofType{producer.ProofTypeZKR0, producer.ProofTypeZKSP1},
			enabledProofTypes(false, false),
		)
	})

	t.Run("force SGX replaces RISC0 and SP1 selection", func(t *testing.T) {
		require.Equal(t, []producer.ProofType{producer.ProofTypeSgx}, enabledProofTypes(true, false))
	})

	t.Run("ZK-only takes precedence over force SGX", func(t *testing.T) {
		require.Equal(
			t,
			[]producer.ProofType{producer.ProofTypeZKR0, producer.ProofTypeZKSP1},
			enabledProofTypes(true, true),
		)
	})
}
