package flags

import (
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"
)

func TestProverRaikoHostFlagRequired(t *testing.T) {
	require.True(t, RaikoHostEndpoint.Required)
}

func TestProverRejectsRemovedProofSelectionFlags(t *testing.T) {
	for _, name := range []string{
		"prover.maxRisc0ProofProposalDistance",
		"prover.forceSP1Proof",
		"prover.sp1ProofPercentage",
		"prover.zkOnlyProofs",
	} {
		t.Run(name, func(t *testing.T) {
			app := cli.NewApp()
			app.Flags = ProverFlags
			err := app.Run([]string{"prover", "--" + name})
			require.ErrorContains(t, err, "flag provided but not defined")
		})
	}
}
