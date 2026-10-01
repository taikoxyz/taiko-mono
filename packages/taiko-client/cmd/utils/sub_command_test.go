package utils

import (
	"flag"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

// newForkTimeContext parses the given arguments with both devnet fork-time flags registered. The
// flags' environment variables are cleared so a harness-exported value can not leak into the test.
func newForkTimeContext(t *testing.T, args ...string) *cli.Context {
	t.Helper()
	t.Setenv("TAIKO_DEVNET_UNZEN_TIME", "")
	t.Setenv("TAIKO_DEVNET_ETNA_TIME", "")

	app := cli.NewApp()
	app.Flags = []cli.Flag{flags.TaikoDevnetUnzenTime, flags.TaikoDevnetEtnaTime}
	set := flag.NewFlagSet("test", 0)
	for _, f := range app.Flags {
		require.NoError(t, f.Apply(set))
	}
	require.NoError(t, set.Parse(args))
	return cli.NewContext(app, set, nil)
}

// pinDevnetForkTimes sets the devnet fork times for one test and restores them afterwards.
func pinDevnetForkTimes(t *testing.T, unzen, etna uint64) {
	t.Helper()
	originalUnzen, originalEtna := gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = originalUnzen, originalEtna })
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = unzen, etna
}

func TestApplyDevnetForkTimeOverrides_EtnaFollowsUnzen(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(t, "--taiko.devnet-unzen-time", "42")))

	require.Equal(t, uint64(42), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(42), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_ExplicitEtna(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(
		t,
		"--taiko.devnet-unzen-time", "100",
		"--taiko.devnet-etna-time", "200",
	)))

	require.Equal(t, uint64(100), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(200), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_EtnaOnly(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(t, "--taiko.devnet-etna-time", "200")))

	require.Equal(t, uint64(0), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(200), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_LeavesPackageVarsWhenFlagsAbsent(t *testing.T) {
	pinDevnetForkTimes(t, 7, 9)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(t)))

	require.Equal(t, uint64(7), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(9), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_RejectsEtnaBeforeUnzen(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	err := applyDevnetForkTimeOverrides(newForkTimeContext(
		t,
		"--taiko.devnet-unzen-time", "100",
		"--taiko.devnet-etna-time", "50",
	))
	require.ErrorContains(t, err, "must not be earlier than")
}
