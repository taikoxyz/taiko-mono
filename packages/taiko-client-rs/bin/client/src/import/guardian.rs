//! A private foreground native process guardian. The controller owns the write end of stdin; EOF on
//! an ordinary shutdown, cancellation, or SIGKILL orders termination of the actual retained child.
//! This also works on macOS, where Linux's PR_SET_PDEATHSIG does not exist.
use std::{
    ffi::OsString,
    io,
    process::{Command, ExitStatus, Stdio},
    time::{Duration, Instant},
};

/// Internal exec marker. It is never part of a saved profile or a public subcommand.
pub(crate) const ARG: &str = "__etna-checkpoint-el-guardian";

/// Start the real helper or EL and wait for its exit or the controller's lifetime pipe. The
/// returned exit code belongs to the child, unless the guard could not start/reap it cleanly; stock
/// verifier exit two is preserved.
pub(crate) fn run(mut args: impl Iterator<Item = OsString>) -> io::Result<ExitStatus> {
    let binary =
        args.next().ok_or_else(|| io::Error::other("missing checkpoint execution binary"))?;
    use std::{io::Write, os::fd::FromRawFd};
    let announce = std::env::var("ETNA_CHILD_ANNOUNCE_FD")
        .ok()
        .map(|value| {
            let fd = value.parse::<i32>().map_err(io::Error::other)?;
            if fd < 3 || unsafe { libc::fcntl(fd, libc::F_SETFD, libc::FD_CLOEXEC) } < 0 {
                return Err(io::Error::other("invalid child announcement channel"))
            }
            // The controller explicitly transferred this descriptor for a single announcement.
            Ok(unsafe { std::fs::File::from_raw_fd(fd) })
        })
        .transpose()?;
    let mut command = Command::new(binary);
    command.env_remove("ETNA_CHILD_ANNOUNCE_FD");
    command.args(args).stdin(Stdio::null());
    let mut child = command.spawn()?;
    if let Some(mut announce) = announce &&
        announce.write_all(&child.id().to_be_bytes()).is_err()
    {
        let _ = child.kill();
        return child.wait()
    }

    let mut fd = libc::pollfd { fd: libc::STDIN_FILENO, events: libc::POLLIN, revents: 0 };
    loop {
        if let Some(status) = child.try_wait()? {
            return Ok(status)
        }
        // No other descriptor is observed. A closed writer reports POLLHUP; any unexpected
        // input or descriptor error also fails closed and stops just our own child.
        let r = unsafe { libc::poll(&mut fd, 1, 100) };
        if r > 0 || (r < 0 && io::Error::last_os_error().kind() != io::ErrorKind::Interrupted) {
            break
        }
    }
    // We retained the unreaped child directly, so this PID cannot refer to a reused process.
    unsafe { libc::kill(child.id() as i32, libc::SIGTERM) };
    let deadline = Instant::now() + Duration::from_secs(60);
    loop {
        if let Some(s) = child.try_wait()? {
            return Ok(s)
        }
        if Instant::now() >= deadline {
            child.kill()?;
            return child.wait()
        }
        std::thread::sleep(Duration::from_millis(50));
    }
}
