package utils

import (
	"flag"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

func TestApplyDevnetUzenTimeOverride_SetsGethPackageVar(t *testing.T) {
	original := gethcore.InternalUzenTime
	t.Cleanup(func() { gethcore.InternalUzenTime = original })

	app := cli.NewApp()
	app.Flags = []cli.Flag{flags.TaikoDevnetUzenTime}
	set := flag.NewFlagSet("test", 0)
	require.NoError(t, flags.TaikoDevnetUzenTime.Apply(set))
	require.NoError(t, set.Parse([]string{"--taiko.devnet-uzen-time", "42"}))
	ctx := cli.NewContext(app, set, nil)

	applyDevnetUzenTimeOverride(ctx)

	require.Equal(t, uint64(42), gethcore.InternalUzenTime)
}

func TestApplyDevnetUzenTimeOverride_LeavesPackageVarWhenFlagAbsent(t *testing.T) {
	original := gethcore.InternalUzenTime
	t.Cleanup(func() { gethcore.InternalUzenTime = original })
	gethcore.InternalUzenTime = 7

	app := cli.NewApp()
	app.Flags = []cli.Flag{flags.TaikoDevnetUzenTime}
	set := flag.NewFlagSet("test", 0)
	require.NoError(t, flags.TaikoDevnetUzenTime.Apply(set))
	require.NoError(t, set.Parse([]string{}))
	ctx := cli.NewContext(app, set, nil)

	applyDevnetUzenTimeOverride(ctx)

	require.Equal(t, uint64(7), gethcore.InternalUzenTime)
}
