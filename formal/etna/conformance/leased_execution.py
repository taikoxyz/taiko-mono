"""Leased execution for the public boundary components.

The historical unleased runner and its input pins remain unchanged. Descendant
cleanup is delegated to that runner's single authoritative implementation.
"""
from contextlib import contextmanager, nullcontext
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import run_comet_signed as SIGNED

LEGACY = SIGNED.COMET.EXECUTION
PATH = Path(__file__).resolve()


# A leased supervisor encodes these outcomes only after confirming quiescence.
# A worker cannot manufacture a completion code by returning it directly.
LEASED_EXIT_CODES = {0: 200, 1: 201, 124: 202, 125: 203, 130: 204}
LEASED_SIGNALS = (signal.SIGTERM, signal.SIGINT)


def _cancellation():
    requested = False

    def cancel(signum, frame):
        nonlocal requested
        requested = True

    return cancel, lambda: requested


@contextmanager
def cancellation_scope():
    """Record cancellation across a whole private mutation and its restoration."""
    cancel, cancelled = _cancellation()
    previous = {}
    try:
        for signum in LEASED_SIGNALS:
            previous[signum] = signal.signal(signum, cancel)
        yield cancelled
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def _wait_leased_worker(child, timeout, cancelled):
    deadline = time.monotonic() + timeout
    while not cancelled():
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return 124
        try:
            return child.wait(timeout=min(remaining, .1))
        except subprocess.TimeoutExpired:
            continue
    return 130


def supervise_leased(argv):
    """Hold the inherited cache file description through descendant cleanup."""
    import ctypes

    lease_fd, parent = map(int, argv[:2])
    timeout, cwd, command = float(argv[2]), argv[3], argv[4:]
    cancel, cancelled = _cancellation()
    for signum in LEASED_SIGNALS:
        signal.signal(signum, cancel)
    signal.pthread_sigmask(signal.SIG_UNBLOCK, LEASED_SIGNALS)
    try:
        os.fstat(lease_fd)
    except OSError:
        return LEASED_EXIT_CODES[125]
    libc = ctypes.CDLL(None, use_errno=True)
    if (not hasattr(os, 'pidfd_open') or not hasattr(signal, 'pidfd_send_signal')
            or libc.prctl(36, 1, 0, 0, 0) != 0 or libc.prctl(1, signal.SIGTERM, 0, 0, 0) != 0
            or os.getppid() != parent):
        return LEASED_EXIT_CODES[125]

    code, error = 130, None
    cleanup_failed = False
    try:
        if not cancelled():
            child = subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL, close_fds=True)
            code = _wait_leased_worker(child, timeout, cancelled)
    except (OSError, ValueError) as exc:
        code, error = 125, str(exc)
    finally:
        while True:
            try:
                if LEGACY._cleanup_descendants():
                    break
            except Exception:
                # An error inspecting descendants gives no basis to release the lease.
                pass
            cleanup_failed = True
            time.sleep(.1)

    if cleanup_failed:
        code, error = 125, 'ETNA DESCENDANT CLEANUP REQUIRED RETRY'
    if error is not None:
        try:
            print(error, file=sys.stderr)
        except OSError:
            pass  # The caller may already be dead and its output pipe closed.
    return LEASED_EXIT_CODES.get(code, LEASED_EXIT_CODES[125])


def _start_supervisor(argv, **options):
    return subprocess.Popen(argv, env={'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8'},
                            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            start_new_session=True, **options)


def _leased_result(status):
    for code, completed in LEASED_EXIT_CODES.items():
        if status == completed:
            return code
    # A dead supervisor may still have surviving descendants. The caller's
    # lease and private source must stay in place until independently cleared.
    try:
        print(f'INCONCLUSIVE: unexpected leased supervisor status {status}; cache lease retained',
              file=sys.stderr, flush=True)
    except OSError:
        pass
    while True:
        signal.pause()


def _execute_leased(argv, cwd, timeout, lease_fd, cancellation):
    if type(lease_fd) is not int or lease_fd < 3:
        raise ValueError('execution lease requires a non-stdio descriptor')
    start = time.monotonic()
    supervisor = [sys.executable, '-B', str(Path(__file__).resolve()), '--_supervise_leased',
                  str(lease_fd), str(os.getpid()), str(timeout), str(cwd), *argv]
    scope = cancellation_scope() if cancellation is None else nullcontext(cancellation)
    forced = None
    with scope as cancelled:
        if not callable(cancelled):
            raise ValueError('execution cancellation requires a shared predicate')
        if cancelled():
            raise ValueError('INCONCLUSIVE: execution cancelled before supervisor start')
        # The inherited mask queues a cancellation until the child installs its
        # recorder. The caller uses the same recorder throughout its campaign.
        mask = signal.pthread_sigmask(signal.SIG_BLOCK, LEASED_SIGNALS)
        try:
            process = _start_supervisor(supervisor, pass_fds=(lease_fd,))
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, mask)
        try:
            while True:
                if forced is None:
                    if cancelled():
                        forced = 130
                    elif time.monotonic() - start >= timeout + 10:
                        forced = 124
                    if forced is not None:
                        process.terminate()
                try:
                    output, _ = process.communicate(timeout=.1)
                    break
                except subprocess.TimeoutExpired:
                    status = process.poll()
                    if status is not None and status not in LEASED_EXIT_CODES.values():
                        # A surviving writer can keep the pipe open after lost
                        # supervision. Retain the lease without waiting for EOF.
                        _leased_result(status)
        except BaseException:
            try:
                process.terminate()
            finally:
                process.stdout.close()
                _leased_result(process.wait())
            raise
        code = _leased_result(process.returncode)
        if forced is not None or cancelled():
            code = forced if forced is not None else 130
    return {'argv': argv, 'supervisor_argv': supervisor, 'supervisor_returncode': process.returncode,
            'returncode': code, 'timeout': code == 124, 'seconds': time.monotonic() - start,
            'output': output.decode(errors='replace')}


def execute(argv, cwd, timeout, *, lease_fd, cancellation=None):
    if not isinstance(argv, list) or not argv or not all(isinstance(x, str) for x in argv):
        raise ValueError('execution requires argv array')
    return _execute_leased(argv, cwd, timeout, lease_fd, cancellation)


if __name__ == '__main__':
    if sys.argv[1:2] != ['--_supervise_leased']:
        raise SystemExit(125)
    raise SystemExit(supervise_leased(sys.argv[2:]))
