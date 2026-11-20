// etna-signer delegates signing and anti-double-sign persistence to CometBFT's
// pinned FilePV, authorizing each signature against the local app trust session. It serves
// one full chain_id from that chain's own HRS state, which init-state created and logged.
package main

import (
	"errors"
	"flag"
	"fmt"
	"math"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	"github.com/cometbft/cometbft/types"
)

// Resolve directory and file symlinks before both owner locking and FilePV loading.
// FilePV atomically replaces the state path, so loading via an alias would fork HRS.
func existingFile(path string) (string, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	canonical, err := filepath.EvalSymlinks(absolute)
	if err != nil {
		return "", err
	}
	info, err := os.Stat(canonical)
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() {
		return "", errors.New("signing file must be regular")
	}
	return canonical, nil
}

// Hard links cannot be canonicalized to a unique pathname and FilePV's atomic
// replacement would split them. Refuse this configuration without changing it.
func singleLinkState(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || stat.Nlink != 1 {
		return errors.New("signing state must have exactly one filesystem link")
	}
	return nil
}

// validTrustTimeout bounds each private trust-control query. A signing request's whole trust
// decision is bounded by signingHold, which caps every query in it; a query never outlives the
// timeout, so a hung app cannot hold one round longer than this (SYNC-9-11).
func validTrustTimeout(d time.Duration) bool {
	return d > 0 && d <= 2*time.Second
}

func run() error {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "keygen":
			return keygen(os.Args[2:], os.Stdout)
		case "pop":
			return pop(os.Args[2:], os.Stdout)
		case "init-domains-log":
			return initDomainsLogCommand(os.Args[2:])
		case "init-state":
			return initStateCommand(os.Args[2:])
		case "transport-keygen":
			return transportKeygen(os.Args[2:], os.Stdout)
		}
	}
	addr := flag.String("comet-signer-addr", "", "Comet's signer listener: unix://<path> or noise://<comet-node-peer-id>@<ip>:<port>; bare tcp:// is refused")
	transportKey := flag.String("transport-key", "", "the signer's persistent Ed25519 Noise transport key (transport-keygen), required for noise:// and refused for unix://")
	control := flag.String("trust-socket", "", "private <app-store>/checkpoint-trust.sock")
	chain := flag.String("chain-id", "", "verified full Comet chain ID; the signer serves only this signing domain")
	key := flag.String("priv-key", "", "existing registered Comet FilePV private key")
	state := flag.String("priv-state", "", "existing <state-dir>/<chain-id>.json HRS that init-state created (never reset)")
	domains := flag.String("domains-log", "", "existing domains log listing every initialized chain ID, outside the state directory")
	denial := flag.String("denial-file", "", "private atomic refusal event file for the local supervisor")
	timeout := flag.Duration("trust-timeout", time.Second, "per-query private control deadline (0 < timeout <= 2s); a signing request's whole trust decision takes at most 3.5s")
	flag.Parse()
	if flag.NArg() != 0 || *addr == "" || *control == "" || *chain == "" || *key == "" || *state == "" || *domains == "" || !validTrustTimeout(*timeout) {
		return errors.New("all addresses, chain ID, existing key/state paths and the domains log are required; timeout must be in (0,2s]")
	}
	signer, release, err := openSigningState(*chain, *key, *state, *domains)
	if err != nil {
		return err
	}
	defer release()
	dial, err := cometDialer(*addr, *transportKey)
	if err != nil {
		return err
	}
	logger := log.NewTMLogger(log.NewSyncWriter(os.Stderr))
	gate := newGate(*control, *timeout)
	gate.hold = signingHold
	gate.denialPath = *denial
	gate.authorized = func(r *trustResponse) {
		logger.Info("checkpoint_trust_authorized", "session", r.SessionID)
	}
	gate.unavailable = func(err error) {
		logger.Info("checkpoint_trust_session_deferred", "err", err)
	}
	endpoint := privval.NewSignerDialerEndpoint(logger, gate.dialer(dial), privval.SignerDialerEndpointConnRetries(math.MaxInt), privval.SignerDialerEndpointRetryWaitInterval(250*time.Millisecond))
	server := privval.NewSignerServer(endpoint, *chain, signer)
	server.SetRequestHandler(gate.handle)
	if err := server.Start(); err != nil {
		return err
	}
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(signals)
	return awaitSignerShutdown(server, gate, signals)
}

// awaitSignerShutdown joins and fences the stock request handler before deciding
// the exit status, retaining uncertainty discovered during ordinary signal shutdown.
// The caller owns signal registration and the signing server.
func awaitSignerShutdown(server *privval.SignerServer, gate *gate, signals <-chan os.Signal) error {
	var terminal error
	select {
	case <-signals:
	case terminal = <-gate.terminal:
	}
	gate.closeTransports()
	stopErr := server.Stop()
	// Stock Stop only closes transport. SetRequestHandler holds the stock handler
	// mutex until an active request finishes and fences any already-decoded request
	// that has not started yet, so no later handler can discover an omitted failure.
	server.SetRequestHandler(func(types.PrivValidator, pv.Message, string) (pv.Message, error) {
		return pv.Message{}, errors.New("signer stopped")
	})
	gate.session.Store(nil)
	select {
	case err := <-gate.terminal:
		terminal = errors.Join(terminal, err)
	default:
	}
	return errors.Join(terminal, stopErr)
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		if errors.Is(err, errSigningStateUnsafe) {
			os.Exit(exitSigningStateUnsafe)
		}
		os.Exit(1)
	}
}
