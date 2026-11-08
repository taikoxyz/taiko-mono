package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

// fenceSuffix names a chain's fence beside its own HRS state, never in the app store or Comet home.
const fenceSuffix = ".uncertain"

// fencePath is the fence of the HRS state at state.
func fencePath(state string) string { return state + fenceSuffix }

// inflightSuffix names the marker a signing step keeps beside its HRS state while it
// synchronizes that state.
const inflightSuffix = ".inflight"

// inflightPath is the inflight marker of the HRS state at state.
func inflightPath(state string) string { return state + inflightSuffix }

// markInflight records, before a signing step synchronizes its state, the boot it runs in. It
// is not fsynced: it guards only a restart on this boot, where the page cache can still show a
// state whose failed fsync was already reported and cleared, so a later fsync succeeds over
// data that never reached disk. A reboot drops that cache, so a marker from another boot is
// harmless and a restart ignores it (RECOV-8.2-3, SYNC-9-13).
func markInflight(path string) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return fmt.Errorf("inflight marker %s: %w", path, err)
	}
	_, err = f.WriteString(bootID() + "\n")
	if err = errors.Join(err, f.Close()); err != nil {
		return fmt.Errorf("inflight marker %s: %w", path, err)
	}
	return nil
}

// refuseInflight refuses a marker that a signing step of this boot left behind: the signer
// died between starting to synchronize its state and either finishing or writing the fence,
// so the latest HRS is uncertain. A regular file naming another boot is stale and ignored. An
// unreadable boot, an empty or unreadable marker, or any other inode refuses.
func refuseInflight(path string) error {
	info, err := os.Lstat(path)
	switch {
	case os.IsNotExist(err):
		return nil
	case err != nil:
	case !info.Mode().IsRegular() || info.Size() > 128:
		err = fmt.Errorf("not a small regular file: %v", info.Mode())
	default:
		var raw []byte
		if raw, err = os.ReadFile(path); err == nil {
			marked, current := strings.TrimSpace(string(raw)), bootID()
			if marked != "" && current != "" && marked != current {
				return nil
			}
			err = fmt.Errorf("boot %q, current boot %q", marked, current)
		}
	}
	return fmt.Errorf("%w: inflight marker %s: a signing step was synchronizing its state on this boot when the signer stopped, and that fsync may have failed; inspect the kernel log and the signer's stderr (%v)", errSigningStateUnsafe, path, err)
}

// unsafeMarkerSuffix names the supervisor's signer-unsafe marker for one chain_id. The
// supervisor writes it beside the domains log, on that log's own volume, whenever it records an
// exit 3, a fence or a signer it had to kill, so the evidence survives a fresh app store.
const unsafeMarkerSuffix = ".signer-unsafe"

// unsafeMarkerPath is chain's signer-unsafe marker in the directory of the domains log at log.
func unsafeMarkerPath(log, chain string) string {
	return filepath.Join(filepath.Dir(log), chain+unsafeMarkerSuffix)
}

// refuseFence refuses every existing inode, including malformed records and
// aliases. Absence must be positively established before loading signing authority.
func refuseFence(path string) error {
	return refuseEvidence(path, "signer fence")
}

// refuseUnsafeMarker refuses the supervisor's signer-unsafe marker by the same rule as the fence:
// any inode, or any Lstat error but absence, is uncertain signing state (RECOV-8.2-3).
func refuseUnsafeMarker(path string) error {
	return refuseEvidence(path, "signer-unsafe marker")
}

// refuseEvidence is errSigningStateUnsafe unless Lstat establishes that nothing exists at path.
func refuseEvidence(path, what string) error {
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		return fmt.Errorf("%w: inspect retained %s %s (%v)", errSigningStateUnsafe, what, path, err)
	}
	return nil
}

// writeFence records at the fence path that a state or directory fsync failed, so the latest
// HRS is uncertain (RECOV-8.2-3) and a restarted signer refuses it. It never replaces an
// existing inode, which is already a fence. It fsyncs the record, then its directory, and joins
// every error: the caller has latched already, and its exit 3 makes the supervisor latch on
// another volume even when this record's own directory fsync fails.
func writeFence(path string, cause error) error {
	record, err := json.Marshal(map[string]any{"schema": 1, "operation": "FilePV signing", "state": strings.TrimSuffix(path, fenceSuffix), "error": cause.Error()})
	if err != nil {
		return fmt.Errorf("signer fence %s: %w", path, err)
	}
	var errs []error
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	switch {
	case err == nil:
		_, err = f.Write(append(record, '\n'))
		errs = append(errs, err, f.Sync(), f.Close())
	case !errors.Is(err, fs.ErrExist):
		return fmt.Errorf("signer fence %s: %w", path, err)
	}
	if err = errors.Join(append(errs, syncDirectory(filepath.Dir(path)))...); err != nil {
		return fmt.Errorf("signer fence %s: %w", path, err)
	}
	return nil
}
