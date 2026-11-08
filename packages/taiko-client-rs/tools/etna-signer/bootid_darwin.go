package main

import "syscall"

// bootID identifies the running kernel boot; every reboot changes it. Empty when unreadable,
// which fails startup and latches signing.
func bootID() string {
	id, err := syscall.Sysctl("kern.bootsessionuuid")
	if err != nil {
		return ""
	}
	return id
}
