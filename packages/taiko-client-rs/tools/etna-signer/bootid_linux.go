package main

import (
	"os"
	"strings"
)

// bootID identifies the running kernel boot; every reboot changes it, and containers share
// the host's. Empty when unreadable, which inflight markers treat as this boot.
func bootID() string {
	raw, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(raw))
}
