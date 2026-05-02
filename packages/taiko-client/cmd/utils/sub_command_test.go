package utils

import (
	"flag"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

func TestApplyDevnetUnzenTimeOverride_SetsGethPackageVar(t *testing.T) {
	original := gethcore.DevnetUnzenTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime = original })

	app := cli.NewApp()
	app.Flags = []cli.Flag{flags.TaikoDevnetUnzenTime}
	set := flag.NewFlagSet("test", 0)
	require.NoError(t, flags.TaikoDevnetUnzenTime.Apply(set))
	require.NoError(t, set.Parse([]string{"--taiko.devnet-unzen-time", "42"}))
	ctx := cli.NewContext(app, set, nil)

	applyDevnetUnzenTimeOverride(ctx)

	require.Equal(t, uint64(42), gethcore.DevnetUnzenTime)
}

func TestApplyDevnetUnzenTimeOverride_LeavesPackageVarWhenFlagAbsent(t *testing.T) {
	original := gethcore.DevnetUnzenTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime = original })
	gethcore.DevnetUnzenTime = 7

	app := cli.NewApp()
	app.Flags = []cli.Flag{flags.TaikoDevnetUnzenTime}
	set := flag.NewFlagSet("test", 0)
	require.NoError(t, flags.TaikoDevnetUnzenTime.Apply(set))
	require.NoError(t, set.Parse([]string{}))
	ctx := cli.NewContext(app, set, nil)

	applyDevnetUnzenTimeOverride(ctx)

	require.Equal(t, uint64(7), gethcore.DevnetUnzenTime)
}
