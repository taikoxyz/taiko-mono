package utils

import (
	"context"
	"flag"
	"net"
	"os"
	"os/signal"
	"strconv"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

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

// testApp is a SubcommandApplication that starts at once and records whether Close ran.
type testApp struct{ closed atomic.Bool }

func (a *testApp) InitFromCli(context.Context, *cli.Context) error { return nil }
func (a *testApp) Name() string                                    { return "test" }
func (a *testApp) Start() error                                    { return nil }
func (a *testApp) Close(context.Context)                           { a.closed.Store(true) }

// runSubcommandAction runs SubcommandAction for app with metrics served on
// 127.0.0.1:port, and returns a channel that receives the action's result.
func runSubcommandAction(app SubcommandApplication, port int) <-chan error {
	cliApp := cli.NewApp()
	cliApp.Flags = []cli.Flag{flags.MetricsEnabled, flags.MetricsAddr, flags.MetricsPort}
	cliApp.Action = SubcommandAction(app)

	errCh := make(chan error, 1)
	go func() {
		errCh <- cliApp.Run([]string{
			"test", "--metrics", "--metrics.addr", "127.0.0.1", "--metrics.port", strconv.Itoa(port),
		})
	}()
	return errCh
}

func freePort(t *testing.T) int {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	port := listener.Addr().(*net.TCPAddr).Port
	require.NoError(t, listener.Close())
	return port
}

func portOpen(port int) bool {
	conn, err := net.DialTimeout("tcp", "127.0.0.1:"+strconv.Itoa(port), time.Second)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}

func TestSubcommandAction_StopsOnFirstSignalWithMetricsEnabled(t *testing.T) {
	// Also catch SIGTERM in the test, so the signal can never kill the test binary.
	guard := make(chan os.Signal, 1)
	signal.Notify(guard, syscall.SIGTERM)
	t.Cleanup(func() { signal.Stop(guard) })

	app := &testApp{}
	port := freePort(t)
	errCh := runSubcommandAction(app, port)

	require.Eventually(t, func() bool { return portOpen(port) }, 5*time.Second, 10*time.Millisecond)
	// The action starts listening for signals right after the metrics server starts.
	time.Sleep(200 * time.Millisecond)

	self, err := os.FindProcess(os.Getpid())
	require.NoError(t, err)
	require.NoError(t, self.Signal(syscall.SIGTERM))

	select {
	case err := <-errCh:
		require.NoError(t, err)
	case <-time.After(5 * time.Second):
		t.Fatal("application did not stop after one SIGTERM")
	}
	require.True(t, app.closed.Load())
	require.Eventually(t, func() bool { return !portOpen(port) }, 5*time.Second, 10*time.Millisecond)
}

func TestSubcommandAction_ClosesAppWhenMetricsFailToStart(t *testing.T) {
	busy, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	t.Cleanup(func() { _ = busy.Close() })

	app := &testApp{}
	errCh := runSubcommandAction(app, busy.Addr().(*net.TCPAddr).Port)

	select {
	case err := <-errCh:
		require.Error(t, err)
	case <-time.After(5 * time.Second):
		t.Fatal("action did not return after the metrics server failed to start")
	}
	require.True(t, app.closed.Load())
}
