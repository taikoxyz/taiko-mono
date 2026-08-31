package flags_test

import (
	"flag"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

func newWSContext(l1, l2 string) *cli.Context {
	set := flag.NewFlagSet("test", flag.ContinueOnError)
	set.String(flags.L1WSEndpoint.Name, l1, "")
	set.String(flags.L2WSEndpoint.Name, l2, "")
	return cli.NewContext(nil, set, nil)
}

func TestCheckWSEndpointsRequired(t *testing.T) {
	// Both present: no error.
	require.NoError(t, flags.CheckWSEndpointsRequired(newWSContext("ws://l1", "ws://l2"), "proposer"))

	// L1 missing: error names the L1 flag and the component.
	err := flags.CheckWSEndpointsRequired(newWSContext("", "ws://l2"), "proposer")
	require.ErrorContains(t, err, "--"+flags.L1WSEndpoint.Name)
	require.ErrorContains(t, err, "proposer")

	// L2 missing: error names the L2 flag and the component.
	err = flags.CheckWSEndpointsRequired(newWSContext("ws://l1", ""), "prover")
	require.ErrorContains(t, err, "--"+flags.L2WSEndpoint.Name)
	require.ErrorContains(t, err, "prover")
}
