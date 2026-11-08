package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/cometbft/cometbft/crypto"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// The domains log records, one line per full chain_id, every stock HRS state ever initialized
// for this key: `etna-signer-domains-v1\n` followed by exactly one `<chain_id>\n` per chain. It
// lives on a different volume from the HRS states, so losing a state file is detectable: a
// logged chain without its state is lost signing state, never a fresh start (RECOV-8.2-1/3).
const domainsLogHeader = "etna-signer-domains-v1"

// errSigningStateUnsafe marks signing state that is lost or whose latest value is uncertain:
// a missing or malformed domains log, a chain absent from it, a logged chain's missing state,
// an unauthentic or ambiguous HRS, a retained fence or a failed fsync. The signer stops signing
// and exits exitSigningStateUnsafe, which the supervisor latches; deleting or recreating state
// never restores service (RECOV-8.2-3).
var errSigningStateUnsafe = errors.New("signing state lost or uncertain (RECOV-8.2-3)")

// exitSigningStateUnsafe is the exit status for errSigningStateUnsafe. Configuration, transport
// and lock errors exit 1.
const exitSigningStateUnsafe = 3

// unsafeState wraps a refusal of the signing state as errSigningStateUnsafe.
func unsafeState(format string, args ...any) error {
	return fmt.Errorf("%w: %s", errSigningStateUnsafe, fmt.Sprintf(format, args...))
}

// maxDomainsLog bounds the log a signer reads.
const maxDomainsLog = 1 << 20

// maxChainIDLen is stock CometBFT's types.MaxChainIDLen.
const maxChainIDLen = 50

// validChainID accepts the stock length and the Etna `etna-<base64url>` charset, so a chain ID
// is always one log line and one file name (START-10-15).
func validChainID(c string) error {
	if len(c) == 0 || len(c) > maxChainIDLen {
		return fmt.Errorf("chain ID must have 1 to %d characters", maxChainIDLen)
	}
	for _, r := range c {
		if !(r >= 'A' && r <= 'Z' || r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '_' || r == '-') {
			return errors.New("chain ID must match [A-Za-z0-9_-]")
		}
	}
	return nil
}

// zeroHRS is the stock unsigned FilePV state, byte for byte as stock FilePV saves it.
func zeroHRS() []byte {
	raw, err := cmtjson.MarshalIndent(privval.FilePVLastSignState{}, "", "  ")
	if err != nil {
		panic(err)
	}
	return raw
}

// syncDirectory makes a created, renamed or removed directory entry durable.
func syncDirectory(path string) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	return f.Sync()
}

// exclusiveDurable creates a new mode-0600 file, never replacing any existing inode, and
// returns only once its bytes and its directory entry are durable.
func exclusiveDurable(path string, data []byte) error {
	f, e := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if e != nil {
		return e
	}
	defer f.Close()
	if _, e = f.Write(data); e != nil {
		return e
	}
	if e = f.Sync(); e != nil {
		return e
	}
	return syncDirectory(filepath.Dir(path))
}

// ownerLock takes a nonblocking exclusive flock on a single-link lock file (RECOV-8.2-2).
func ownerLock(path string) (*os.File, error) {
	f, e := os.OpenFile(path, os.O_CREATE|os.O_RDWR|syscall.O_NOFOLLOW, 0600)
	if e != nil {
		return nil, e
	}
	if e = singleLinkState(path); e == nil {
		e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
	}
	if e != nil {
		f.Close()
		return nil, fmt.Errorf("another signer owns signing authority: %w", e)
	}
	return f, nil
}

// validateHRS reads using stock codecs and authenticates persisted canonical bytes with the
// registered public key. Unsigned means exactly the stock zero state, never an arbitrary HRS.
func validateHRS(path, chain string, pub crypto.PubKey) (bool, error) {
	canonical, e := existingFile(path)
	if e != nil {
		return false, e
	}
	if canonical != path {
		return false, errors.New("domain HRS must be canonical")
	}
	if e = singleLinkState(path); e != nil {
		return false, e
	}
	raw, e := os.ReadFile(path)
	if e != nil {
		return false, e
	}
	var fields map[string]json.RawMessage
	if e = json.Unmarshal(raw, &fields); e != nil {
		return false, e
	}
	if e = uniqueJSON(json.NewDecoder(bytes.NewReader(raw))); e != nil {
		return false, e
	}
	for _, key := range []string{"height", "round", "step"} {
		v, ok := fields[key]
		if !ok || bytes.Equal(bytes.TrimSpace(v), []byte("null")) {
			return false, errors.New("missing HRS field")
		}
	}
	for key := range fields {
		switch key {
		case "height", "round", "step", "signature", "signbytes":
		default:
			return false, errors.New("unknown HRS field")
		}
	}
	var s privval.FilePVLastSignState
	if e = cmtjson.Unmarshal(raw, &s); e != nil {
		return false, e
	}
	if s.Height == 0 && s.Round == 0 && s.Step == 0 && len(s.Signature) == 0 && len(s.SignBytes) == 0 {
		return true, nil
	}
	if s.Height <= 0 || s.Round < 0 || len(s.Signature) == 0 || len(s.SignBytes) == 0 || !pub.VerifySignature(s.SignBytes, s.Signature) {
		return false, errors.New("ambiguous or unauthentic HRS")
	}
	var domain string
	var height int64
	var round int64
	switch s.Step {
	case 1:
		var p tm.CanonicalProposal
		if e = protoio.UnmarshalDelimited(s.SignBytes, &p); e != nil {
			return false, e
		}
		if p.Type != tm.ProposalType {
			return false, errors.New("invalid proposal HRS")
		}
		domain, height, round = p.ChainID, p.Height, p.Round
	case 2, 3:
		var v tm.CanonicalVote
		if e = protoio.UnmarshalDelimited(s.SignBytes, &v); e != nil {
			return false, e
		}
		if (s.Step == 2 && v.Type != tm.PrevoteType) || (s.Step == 3 && v.Type != tm.PrecommitType) {
			return false, errors.New("invalid vote HRS")
		}
		domain, height, round = v.ChainID, v.Height, v.Round
	default:
		return false, errors.New("invalid HRS step")
	}
	if domain != chain || height != s.Height || round != int64(s.Round) {
		return false, errors.New("signed HRS domain/height/round mismatch")
	}
	return false, nil
}

// initDomainsLog creates the log with only its header, durably, and never replaces or follows
// an existing path.
func initDomainsLog(path string) (err error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := f.Close(); err == nil {
			err = closeErr
		}
		if err != nil {
			// Only the file created here, holding no chain, is removed.
			err = errors.Join(err, os.Remove(path))
		}
	}()
	if err = f.Chmod(0600); err != nil {
		return err
	}
	if _, err = f.Write([]byte(domainsLogHeader + "\n")); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	return syncDirectory(filepath.Dir(path))
}

// readDomainsLog returns the logged chains. A wrong header, a missing final newline (a torn
// append), a blank or invalid line, a duplicate or an oversize log is malformed.
func readDomainsLog(f *os.File) (map[string]bool, error) {
	info, err := f.Stat()
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, errors.New("domains log must be a regular file")
	}
	raw, err := io.ReadAll(io.NewSectionReader(f, 0, maxDomainsLog+1))
	if err != nil {
		return nil, err
	}
	if len(raw) > maxDomainsLog {
		return nil, errors.New("domains log exceeds 1 MiB")
	}
	body, ok := bytes.CutPrefix(raw, []byte(domainsLogHeader+"\n"))
	if !ok {
		return nil, errors.New("domains log has no etna-signer-domains-v1 header")
	}
	if len(body) > 0 && body[len(body)-1] != '\n' {
		return nil, errors.New("domains log ends in a torn line")
	}
	logged := map[string]bool{}
	if len(body) == 0 {
		return logged, nil
	}
	for _, line := range strings.Split(string(body[:len(body)-1]), "\n") {
		if line == "" {
			return nil, errors.New("blank domains log line")
		}
		if err := validChainID(line); err != nil {
			return nil, fmt.Errorf("invalid domains log line: %w", err)
		}
		if logged[line] {
			return nil, fmt.Errorf("duplicate domains log line %s", line)
		}
		logged[line] = true
	}
	return logged, nil
}

// statePlacement checks that the state file is named `<chain>.json` and that the domains log is
// in another directory, so a lost state volume cannot also take the evidence of its chains.
func statePlacement(chain, state, log string) error {
	if err := validChainID(chain); err != nil {
		return err
	}
	if filepath.Base(state) != chain+".json" {
		return fmt.Errorf("signing state must be named %s.json", chain)
	}
	stateDir, err := filepath.Abs(filepath.Dir(state))
	if err != nil {
		return err
	}
	logDir, err := filepath.Abs(filepath.Dir(log))
	if err != nil {
		return err
	}
	if stateDir == logDir {
		return errors.New("domains log must be outside the signing state directory")
	}
	// Directory aliases resolve to the same canonical directory.
	stateCanonical, stateErr := filepath.EvalSymlinks(stateDir)
	logCanonical, logErr := filepath.EvalSymlinks(logDir)
	if stateErr == nil && logErr == nil && stateCanonical == logCanonical {
		return errors.New("domains log must be outside the signing state directory")
	}
	return nil
}

// initState creates chain's stock zero HRS and then logs the chain, both durably. It holds the
// key's owner lock and the log's exclusive lock throughout, so it never runs beside a serving
// signer for this key. It refuses a logged chain and an existing state file, so an HRS is never
// reset (RECOV-8.2-1). An interruption after the state and before the log line leaves an unlogged
// zero state that serve and init-state both refuse: after checking it equals zeroHRS(), the
// operator removes it and reruns this command. The log is never edited by hand.
func initState(chain, key, state, log string) error {
	if err := statePlacement(chain, state, log); err != nil {
		return err
	}
	key, err := existingFile(key)
	if err != nil {
		return fmt.Errorf("existing signing key: %w", err)
	}
	if err = singleLinkState(key); err != nil {
		return err
	}
	if _, err = loadNativeKey(key); err != nil {
		return err
	}
	keyLock, err := ownerLock(key + ".lock")
	if err != nil {
		return err
	}
	defer keyLock.Close()
	journal, err := os.OpenFile(log, os.O_RDWR|os.O_APPEND|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return fmt.Errorf("domains log: %w", err)
	}
	defer journal.Close()
	if err = syscall.Flock(int(journal.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return fmt.Errorf("another signer owns the domains log: %w", err)
	}
	logged, err := readDomainsLog(journal)
	if err != nil {
		return fmt.Errorf("domains log: %w", err)
	}
	if logged[chain] {
		return fmt.Errorf("chain %s is already initialized; its HRS is never reset", chain)
	}
	if err = createZeroState(state); err != nil {
		return fmt.Errorf("new signing state: %w", err)
	}
	// One write: an append is the whole line or, after a crash, a torn line that makes the log
	// malformed, which serve refuses.
	if _, err = journal.Write([]byte(chain + "\n")); err != nil {
		return fmt.Errorf("append %s to the domains log: %w", chain, err)
	}
	if err = journal.Sync(); err != nil {
		return fmt.Errorf("domains log: %w", err)
	}
	return syncDirectory(filepath.Dir(log))
}

// createZeroState exclusively creates state as the stock zero HRS, durably. A failed write
// removes only the file created here: it is unlogged, so nothing has signed with it.
func createZeroState(state string) (err error) {
	f, err := os.OpenFile(state, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := f.Close(); err == nil {
			err = closeErr
		}
		if err != nil {
			err = errors.Join(err, os.Remove(state))
		}
	}()
	if _, err = f.Write(zeroHRS()); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	return syncDirectory(filepath.Dir(state))
}

// openSigningState opens chain's HRS for serving, in this order: the chain ID, the state's
// name and the log's directory (configuration, exit 1); the key and its owner flock (exit 1 on
// contention); the domains log under a shared flock, which must list chain; the state, which a
// logged chain must have, and its owner flock; the fence; and the HRS, authenticated by the key
// for chain. A refusal of the state itself is errSigningStateUnsafe: nothing is created or reset,
// and a lost state is never mistaken for a fresh start (RECOV-8.2-1..3). release closes the
// locks, which the caller holds while serving (RECOV-8.2-2).
func openSigningState(chain, key, state, log string) (_ *durableFilePV, release func(), err error) {
	if err = statePlacement(chain, state, log); err != nil {
		return nil, nil, err
	}
	var locks []*os.File
	unlock := func() {
		for i := len(locks) - 1; i >= 0; i-- {
			locks[i].Close()
		}
	}
	defer func() {
		if err != nil {
			unlock()
		}
	}()
	// Key ownership prevents two state paths, or two hosts sharing a volume, using one key.
	canonicalKey, err := existingFile(key)
	if err != nil {
		return nil, nil, fmt.Errorf("existing signing file %s: %w", key, err)
	}
	key = canonicalKey
	if err = singleLinkState(key); err != nil {
		return nil, nil, err
	}
	native, err := loadNativeKey(key)
	if err != nil {
		return nil, nil, err
	}
	keyLock, err := ownerLock(key + ".lock")
	if err != nil {
		return nil, nil, err
	}
	locks = append(locks, keyLock)
	journal, err := os.OpenFile(log, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return nil, nil, unsafeState("domains log %s: %v", log, err)
	}
	locks = append(locks, journal)
	if err = syscall.Flock(int(journal.Fd()), syscall.LOCK_SH|syscall.LOCK_NB); err != nil {
		return nil, nil, fmt.Errorf("another signer owns the domains log: %w", err)
	}
	logged, err := readDomainsLog(journal)
	if err != nil {
		return nil, nil, unsafeState("domains log %s: %v", log, err)
	}
	if !logged[chain] {
		return nil, nil, unsafeState("chain %s is not initialized in domains log %s; a state that init-state did not log is never used", chain, log)
	}
	canonical, err := existingFile(state)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil, unsafeState("signing state %s of logged chain %s is missing: %v", state, chain, err)
	}
	if err != nil {
		return nil, nil, unsafeState("signing state %s: %v", state, err)
	}
	// An alias must resolve to this chain's own state, never another chain's.
	if filepath.Base(canonical) != chain+".json" {
		return nil, nil, unsafeState("signing state %s resolves to %s, not %s.json", state, canonical, chain)
	}
	if err = singleLinkState(canonical); err != nil {
		return nil, nil, unsafeState("signing state %s: %v", canonical, err)
	}
	stateLock, err := ownerLock(canonical + ".lock")
	if err != nil {
		return nil, nil, err
	}
	locks = append(locks, stateLock)
	if err = clearUncertainty(uncertaintyPath(canonical)); err != nil {
		return nil, nil, err
	}
	if _, err = validateHRS(canonical, chain, native.PubKey()); err != nil {
		return nil, nil, unsafeState("HRS %s: %v", canonical, err)
	}
	return loadDurableFilePV(key, canonical), unlock, nil
}

// initDomainsLogCommand is `etna-signer init-domains-log --domains-log L`, run once per key.
func initDomainsLogCommand(args []string) error {
	flags := flag.NewFlagSet("init-domains-log", flag.ContinueOnError)
	log := flags.String("domains-log", "", "new domains log path (must not exist), on another volume than the signing state")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *log == "" || flags.NArg() != 0 {
		return errors.New("init-domains-log requires --domains-log only")
	}
	return initDomainsLog(*log)
}

// initStateCommand is `etna-signer init-state`, run once per chain_id with the signer stopped.
func initStateCommand(args []string) error {
	flags := flag.NewFlagSet("init-state", flag.ContinueOnError)
	chain := flags.String("chain-id", "", "full Comet chain ID of the new signing domain")
	key := flags.String("priv-key", "", "existing registered FilePV key")
	state := flags.String("priv-state", "", "new <state-dir>/<chain-id>.json (must not exist)")
	log := flags.String("domains-log", "", "existing domains log")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *chain == "" || *key == "" || *state == "" || *log == "" || flags.NArg() != 0 {
		return errors.New("init-state requires --chain-id, --priv-key, --priv-state and --domains-log")
	}
	return initState(*chain, *key, *state, *log)
}
