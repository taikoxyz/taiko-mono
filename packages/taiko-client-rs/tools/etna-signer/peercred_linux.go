package main

import (
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"syscall"
)

// peerCredentials is the PID and UID of a connected Unix socket's peer, as the kernel recorded
// them when the peer listened or connected (SO_PEERCRED).
func peerCredentials(conn net.Conn) (int, int, error) {
	unix, ok := conn.(*net.UnixConn)
	if !ok {
		return 0, 0, errors.New("not a Unix socket")
	}
	raw, err := unix.SyscallConn()
	if err != nil {
		return 0, 0, err
	}
	var cred *syscall.Ucred
	var credErr error
	if err = raw.Control(func(fd uintptr) {
		cred, credErr = syscall.GetsockoptUcred(int(fd), syscall.SOL_SOCKET, syscall.SO_PEERCRED)
	}); err != nil {
		return 0, 0, err
	}
	if credErr != nil {
		return 0, 0, credErr
	}
	return int(cred.Pid), int(cred.Uid), nil
}

// processStart is a live process's start time in clock ticks since boot (/proc/<pid>/stat field
// 22), which with the PID identifies the process across PID reuse.
func processStart(pid int) (string, error) {
	raw, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return "", err
	}
	// The command name, field 2, is parenthesized and may hold spaces and parentheses.
	end := strings.LastIndexByte(string(raw), ')')
	if end < 0 {
		return "", errors.New("malformed /proc stat")
	}
	fields := strings.Fields(string(raw[end+1:]))
	// fields[0] is field 3 (state), so field 22 is fields[19].
	if len(fields) < 20 {
		return "", errors.New("malformed /proc stat")
	}
	if _, err = strconv.ParseUint(fields[19], 10, 64); err != nil {
		return "", errors.New("malformed /proc stat start time")
	}
	return fields[19], nil
}
