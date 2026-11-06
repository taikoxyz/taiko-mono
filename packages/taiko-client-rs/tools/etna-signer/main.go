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
func run() error {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "keygen":
			return keygen(os.Args[2:], os.Stdout)
		case "pop":
			return pop(os.Args[2:], os.Stdout)
		}
	}
	addr := flag.String("comet-signer-addr", "", "Comet-owned signer listener (unix:// or tcp:// SecretConnection)")
	control := flag.String("trust-socket", "", "private <app-store>/checkpoint-trust.sock")
	chain := flag.String("chain-id", "", "verified Comet chain ID")
	key := flag.String("priv-key", "", "existing Comet FilePV private key")
	state := flag.String("priv-state", "", "existing Comet FilePV anti-double-sign state (never reset)")
	root := flag.String("authority-root", "", "private durable deployment/key authority directory")
	l1 := flag.String("l1-chain-id", "", "full decimal deployment L1 uint256 ID")
	l2 := flag.String("l2-chain-id", "", "full decimal deployment L2 uint256 ID")
	inbox := flag.String("inbox", "", "canonical 0x lowercase deployment Inbox")
	generation := flag.Uint64("generation", 0, "explicit generation for authority-mode chain ID")
	enroll := flag.Bool("enroll-legacy", false, "explicit one-time legacy enrollment; matching completed enrollment resumes idempotently")
	denial := flag.String("denial-file", "", "private atomic refusal event file for the local supervisor")
	timeout := flag.Duration("trust-timeout", time.Second, "per-request private control deadline (0 < timeout <= 10s)")
	await := flag.Bool("await-trust", false, "recovery restart after a refused signing request, once trust has returned: connect to Comet only after the first transport's fresh trust session is Ready, so WAL replay's re-request of the refused step is authorized; later reconnects dial at once; never for a first start, where trust may return only after Comet syncs")
	flag.Parse()
	if flag.NArg() != 0 || *addr == "" || *control == "" || *chain == "" || *key == "" || *state == "" || *timeout <= 0 || *timeout > 10*time.Second {
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
	var signer types.PrivValidator
	if *root != "" {
		config := authorityConfig{Root: *root, Key: *key, LegacyState: *state, L1ChainID: *l1, L2ChainID: *l2, Inbox: *inbox, EnrollLegacy: *enroll}
		expected, err := config.chainID(*generation)
		if err != nil || expected != *chain {
			return errors.New("authority generation/deployment does not match chain ID")
		}
		authority, err := openAuthority(config)
		if err != nil {
			return err
		}
		defer authority.Close()
		signer = &domainSigner{authority: authority}
	} else {
		if *enroll || *l1 != "" || *l2 != "" || *inbox != "" || *generation != 0 {
			return errors.New("authority options require --authority-root")
		}
		// Key ownership prevents two different state paths using the same native key.
		if err := singleLinkState(*key); err != nil {
			return err
		}
		keyLock, err := ownerLock(*key + ".lock")
		if err != nil {
			return err
		}
		defer keyLock.Close()
		stateLock, err := ownerLock(*state + ".lock")
		if err != nil {
			return err
		}
		defer stateLock.Close()
		for _, p := range []string{*key + ".authority.json", *state + ".authority.json"} {
			if _, err := os.Lstat(p); !os.IsNotExist(err) {
				return errors.New("enrolled signer requires authority mode; missing or uncertain registry requires investigation")
			}
		}
		if _, err := loadNativeKey(*key); err != nil {
			return err
		}
		signer = loadDurableFilePV(*key, *state)
	}
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
	gate.denialPath = *denial
	if *root != "" {
		gate.schema = 2
	}
	gate.authorized = func(r *trustResponse) {
		logger.Info("checkpoint_trust_authorized", "session", r.SessionID, "committed_height", *r.Committed.Height, "target_height", *r.Target.Height)
	}
	gate.connecting = func(r *trustResponse) {
		logger.Info("checkpoint_trust_ready_connected_to_comet", "session", r.SessionID, "committed_height", *r.Committed.Height, "target_height", *r.Target.Height)
	}
	dialer := gate.dialer(dial)
	if *await {
		dialer = gate.trustedDialer(dial, *chain)
	}
	endpoint := privval.NewSignerDialerEndpoint(logger, dialer, privval.SignerDialerEndpointConnRetries(math.MaxInt), privval.SignerDialerEndpointRetryWaitInterval(250*time.Millisecond))
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
		os.Exit(1)
	}
}
