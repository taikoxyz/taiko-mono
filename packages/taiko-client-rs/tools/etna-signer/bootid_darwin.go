package main

import "syscall"

// bootID identifies the running kernel boot; every reboot changes it. Empty when unreadable,
// which inflight markers treat as this boot.
func bootID() string {
	id, err := syscall.Sysctl("kern.bootsessionuuid")
	if err != nil {
		return ""
	}
	return id
}
