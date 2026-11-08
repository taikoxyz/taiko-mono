package main

import (
	"os"
	"strings"
)

// bootID identifies the running kernel boot; every reboot changes it. runc containers share
// the host kernel's; a sandboxed runtime (gVisor, Kata) has its own, which inflight markers
// cannot rely on. Empty when unreadable, which fails startup and latches signing.
func bootID() string {
	raw, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(raw))
}
