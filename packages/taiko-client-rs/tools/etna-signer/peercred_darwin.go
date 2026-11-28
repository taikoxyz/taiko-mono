package main

import (
	"errors"
	"net"

	"golang.org/x/sys/unix"
)

// peerCredentials is the PID and UID of a connected Unix socket's peer (LOCAL_PEERPID and
// LOCAL_PEERCRED).
func peerCredentials(conn net.Conn) (int, int, error) {
	socket, ok := conn.(*net.UnixConn)
	if !ok {
		return 0, 0, errors.New("not a Unix socket")
	}
	raw, err := socket.SyscallConn()
	if err != nil {
		return 0, 0, err
	}
	var pid int
	var cred *unix.Xucred
	var credErr error
	if err = raw.Control(func(fd uintptr) {
		if pid, credErr = unix.GetsockoptInt(int(fd), unix.SOL_LOCAL, unix.LOCAL_PEERPID); credErr == nil {
			cred, credErr = unix.GetsockoptXucred(int(fd), unix.SOL_LOCAL, unix.LOCAL_PEERCRED)
		}
	}); err != nil {
		return 0, 0, err
	}
	if credErr != nil {
		return 0, 0, credErr
	}
	return pid, int(cred.Uid), nil
}

// processStart is empty: without /proc the supervisor reports no start time either, and a
// Comet process is identified by its PID alone.
func processStart(int) (string, error) {
	return "", nil
}
