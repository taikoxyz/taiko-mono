package utils

import (
	"flag"
	"math"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

// newForkTimeContext parses the given arguments with both devnet fork-time flags registered, after setting
// the flags' environment variables from env. Variables that env does not name are cleared, so a
// harness-exported value can not leak into the test. The flags are copies: urfave/cli records an
// environment value on the flag itself, where it would leak into later tests.
func newForkTimeContext(t *testing.T, env map[string]string, args ...string) *cli.Context {
	t.Helper()
	for _, name := range []string{"TAIKO_DEVNET_UNZEN_TIME", "TAIKO_DEVNET_ETNA_TIME"} {
		t.Setenv(name, env[name])
	}

	unzenFlag, etnaFlag := *flags.TaikoDevnetUnzenTime, *flags.TaikoDevnetEtnaTime
	app := cli.NewApp()
	app.Flags = []cli.Flag{&unzenFlag, &etnaFlag}
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

func TestApplyDevnetForkTimeOverrides_UnsetEtnaIsNever(t *testing.T) {
	pinDevnetForkTimes(t, 7, 9)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(t, nil)))

	require.Equal(t, uint64(7), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(math.MaxUint64), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_UnsetEtnaDoesNotFollowUnzen(t *testing.T) {
	pinDevnetForkTimes(t, 0, 500)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(t, nil, "--taiko.devnet-unzen-time", "42")))

	require.Equal(t, uint64(42), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(math.MaxUint64), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_ExplicitEtna(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(
		t,
		nil,
		"--taiko.devnet-unzen-time", "100",
		"--taiko.devnet-etna-time", "200",
	)))

	require.Equal(t, uint64(100), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(200), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_EtnaAtUnzen(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(
		t,
		nil,
		"--taiko.devnet-unzen-time", "100",
		"--taiko.devnet-etna-time", "100",
	)))

	require.Equal(t, uint64(100), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(100), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_EtnaOnly(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(t, nil, "--taiko.devnet-etna-time", "200")))

	require.Equal(t, uint64(0), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(200), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_EtnaFromEnv(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.NoError(t, applyDevnetForkTimeOverrides(newForkTimeContext(
		t,
		map[string]string{"TAIKO_DEVNET_ETNA_TIME": "300"},
	)))

	require.Equal(t, uint64(0), gethcore.DevnetUnzenTime)
	require.Equal(t, uint64(300), gethcore.DevnetEtnaTime)
}

func TestApplyDevnetForkTimeOverrides_RejectsEtnaBeforeUnzen(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	err := applyDevnetForkTimeOverrides(newForkTimeContext(
		t,
		nil,
		"--taiko.devnet-unzen-time", "100",
		"--taiko.devnet-etna-time", "50",
	))
	require.ErrorContains(t, err, "must not be earlier than")
}

func TestApplyDevnetForkTimeOverrides_RejectsEtnaBeforeDefaultUnzen(t *testing.T) {
	pinDevnetForkTimes(t, 100, 0)

	err := applyDevnetForkTimeOverrides(newForkTimeContext(t, nil, "--taiko.devnet-etna-time", "50"))
	require.ErrorContains(t, err, "must not be earlier than")
}
