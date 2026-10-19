// etna-signer delegates signing and anti-double-sign persistence to CometBFT's
// pinned FilePV, authorizing each signature against the local app trust session.
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

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/libs/log"
	cmtnet "github.com/cometbft/cometbft/libs/net"
	"github.com/cometbft/cometbft/privval"
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
func run() error {
	addr := flag.String("comet-signer-addr", "", "Comet-owned signer listener (unix:// or tcp:// SecretConnection)")
	control := flag.String("trust-socket", "", "private <app-store>/checkpoint-trust.sock")
	chain := flag.String("chain-id", "", "verified Comet chain ID")
	key := flag.String("priv-key", "", "existing Comet FilePV private key")
	state := flag.String("priv-state", "", "existing Comet FilePV anti-double-sign state (never reset)")
	timeout := flag.Duration("trust-timeout", time.Second, "per-request private control deadline (0 < timeout <= 10s)")
	flag.Parse()
	if *addr == "" || *control == "" || *chain == "" || *key == "" || *state == "" || *timeout <= 0 || *timeout > 10*time.Second {
		return errors.New("all addresses, chain ID and existing key/state paths are required; timeout must be in (0,10s]")
	}
	for _, path := range []*string{key, state} {
		canonical, err := existingFile(*path)
		if err != nil {
			return fmt.Errorf("existing signing file %s: %w", *path, err)
		}
		*path = canonical
	}
	if err := singleLinkState(*state); err != nil {
		return err
	}
	lock, err := os.OpenFile(*state+".lock", os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return errors.New("another signer owns this FilePV state")
	}
	signer := privval.LoadFilePV(*key, *state)
	var dial privval.SocketDialer
	protocol, address := cmtnet.ProtocolAndAddress(*addr)
	switch protocol {
	case "unix":
		dial = privval.DialUnixFn(address)
	case "tcp":
		dial = privval.DialTCPFn(address, 3*time.Second, ed25519.GenPrivKey())
	default:
		return errors.New("unsupported Comet signer transport")
	}
	logger := log.NewTMLogger(log.NewSyncWriter(os.Stderr))
	gate := newGate(*control, *timeout)
	gate.authorized = func(r *trustResponse) {
		logger.Info("checkpoint_trust_authorized", "session", r.SessionID, "committed_height", *r.Committed.Height, "target_height", *r.Target.Height)
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
	<-signals
	gate.session.Store(nil)
	return server.Stop()
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
