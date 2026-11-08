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
// harmless and a restart ignores it (RECOV-8.2-3, SYNC-9-13). This holds only where the signer
// shares the host kernel (runc): a sandboxed runtime has its own boot ID while the host keeps
// the cache. The marker is created exclusively: startup removed any stale one, and each step
// removes its own, so an existing inode here, a hard link included, is never truncated.
func markInflight(path string) error {
	boot := bootID()
	if boot == "" {
		return fmt.Errorf("inflight marker %s: the kernel boot ID is unreadable", path)
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return fmt.Errorf("inflight marker %s: %w", path, err)
	}
	_, err = f.WriteString(boot + "\n")
	if err = errors.Join(err, f.Close()); err != nil {
		return fmt.Errorf("inflight marker %s: %w", path, err)
	}
	return nil
}

// refuseInflight refuses a marker that a signing step of this boot left behind: the signer
// died between starting to synchronize its state and either finishing or writing the fence,
// so the latest HRS is uncertain. On this boot the page cache holds exactly what markInflight
// wrote: this boot's ID, or nothing if the signer died before writing it, which is before that
// step's first fsync. So only this boot's ID refuses. Empty, zero-filled or any other content is
// what a crash leaves on disk (the directory fsync commits the name before the data) or another
// boot's marker; it is removed, and serving goes on. Any other inode, or more than 128 bytes,
// refuses. An unreadable boot ID fails startup: the marker could not be checked or written.
func refuseInflight(path string) error {
	current := bootID()
	if current == "" {
		return fmt.Errorf("inflight marker %s: the kernel boot ID is unreadable", path)
	}
	info, err := os.Lstat(path)
	switch {
	case os.IsNotExist(err):
		return nil
	case err != nil:
	case !info.Mode().IsRegular() || info.Size() > 128:
		err = fmt.Errorf("not a regular file of at most 128 bytes: %v, %d bytes", info.Mode(), info.Size())
	default:
		var raw []byte
		if raw, err = os.ReadFile(path); err == nil {
			if strings.TrimSpace(string(raw)) != current {
				if err = os.Remove(path); err != nil {
					return fmt.Errorf("stale inflight marker %s: %w", path, err)
				}
				return nil
			}
			err = fmt.Errorf("it names this boot %s", current)
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
