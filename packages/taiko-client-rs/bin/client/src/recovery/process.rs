//! Locally owned children and crash-retained component reservations.

use super::{RecoveryCommandError, profile::Executable};
use abci::ownership::{ActivationLease, ComponentLease, ComponentPaths, ComponentRole, OwnerGrant};
use std::{
    io::Read,
    os::{fd::AsRawFd, unix::net::UnixStream},
    path::PathBuf,
    sync::{Arc, Mutex},
    time::Duration,
};

use tokio::process::{Child, Command};

/// Hold-only descendant lifetime descriptor; never participant or signing authority.
const LIFETIME_ENV: &str = "ETNA_OWNER_LIFETIME_FD";

/// Explicit executable, canonical writer identity and working directory for one child.
pub struct ProcessSpec {
    /// Direct program/argv/environment prefix; no shell interpretation.
    pub executable: Executable,
    /// Canonical writer storage protected by this child's scoped grant.
    pub paths: ComponentPaths,
    /// Explicit working directory; stock Comet must use its installed home.
    pub cwd: PathBuf,
}
/// A real child handle, never a PID reconstructed from disk or a listener.
struct OwnedChild {
    /// Safe stop ordering and duplicate-start identity.
    role: ComponentRole,
    /// Actual spawned child retained until reaped.
    child: Child,
    /// EOF proves all cooperating descendants closed their inherited hold endpoint.
    lifetime: UnixStream,
}
/// Complete ownership retained together by cancellation-safe cleanup.
struct RuntimeState {
    /// Root lock inherited by all children and retained until cleanup ends.
    activation: ActivationLease,
    /// Every old/current reservation must be acquired before the first spawn.
    leases: Vec<ComponentLease>,
    /// Actual spawned processes; no external-service adoption.
    children: Vec<OwnedChild>,
}
/// Foreground runtime; dropping it schedules bounded ordered cleanup of owned handles only.
pub struct OwnedRuntime {
    /// Shared with cancellation-safe cleanup; errors retain actual handles for a later retry.
    state: Arc<Mutex<Option<RuntimeState>>>,
}
impl OwnedRuntime {
    /// Begin with an already acquired controller lease.
    pub fn new(activation: ActivationLease) -> Self {
        Self {
            state: Arc::new(Mutex::new(Some(RuntimeState {
                activation,
                leases: Vec::new(),
                children: Vec::new(),
            }))),
        }
    }
    /// Reserve each declared original/current writer before any launch or stateful probe.
    /// Fencing after the first spawn fails: older children must inherit the entire barrier.
    pub fn fence(&mut self, paths: &ComponentPaths) -> Result<(), RecoveryCommandError> {
        let mut guard = self.state.lock().map_err(|_| RecoveryCommandError::Busy)?;
        let state = guard.as_mut().ok_or(RecoveryCommandError::Busy)?;
        if !state.children.is_empty() {
            return Err(RecoveryCommandError::Busy);
        }
        if let Some(existing) =
            state.leases.iter().find(|lease| lease.paths.directory == paths.directory)
        {
            return if existing.paths.role == paths.role {
                Ok(())
            } else {
                Err(RecoveryCommandError::Busy)
            };
        }
        state
            .leases
            .push(ComponentLease::acquire(paths, None).map_err(|_| RecoveryCommandError::Busy)?);
        Ok(())
    }
    /// Spawn one previously fenced component, retaining its actual handle and scoped grant.
    pub fn spawn(
        &mut self,
        role: ComponentRole,
        spec: &ProcessSpec,
    ) -> Result<(), RecoveryCommandError> {
        if role == ComponentRole::Supervisor &&
            (spec.executable.env.contains_key("ETNA_COMET_CONTAINER") ||
                std::env::var_os("ETNA_COMET_CONTAINER").is_some())
        {
            return Err(RecoveryCommandError::Missing(
                "local foreground supervisor without container adapter",
            ));
        }
        let mut guard = self.state.lock().map_err(|_| RecoveryCommandError::Busy)?;
        let state = guard.as_mut().ok_or(RecoveryCommandError::Busy)?;
        if role != spec.paths.role || state.children.iter().any(|child| child.role == role) {
            return Err(RecoveryCommandError::Busy);
        }
        let index = state
            .leases
            .iter()
            .position(|lease| {
                lease.paths.role == role && lease.paths.directory == spec.paths.directory
            })
            .ok_or(RecoveryCommandError::Missing("fenced component"))?;
        let grant = OwnerGrant::for_child(&state.activation, &state.leases, index)
            .map_err(|_| RecoveryCommandError::Busy)?;
        let mut command = Command::new(&spec.executable.program);
        command
            .args(&spec.executable.argv)
            .envs(&spec.executable.env)
            .envs(grant.environment())
            .current_dir(&spec.cwd)
            // Terminal SIGINT belongs to the controller; it orders actual-handle shutdown.
            .process_group(0)
            .stdin(std::process::Stdio::null());
        let (lifetime, child_lifetime) = UnixStream::pair()
            .map_err(|_| RecoveryCommandError::Runtime("create descendant lifetime"))?;
        lifetime
            .set_nonblocking(true)
            .map_err(|_| RecoveryCommandError::Runtime("configure descendant lifetime"))?;
        command.env(LIFETIME_ENV, child_lifetime.as_raw_fd().to_string());
        if role == ComponentRole::Comet {
            command
                .env_remove(abci::ownership::OWNER_FDS_ENV)
                .env_remove(abci::ownership::OWNER_JOIN_ENV)
                .env_remove(LIFETIME_ENV);
        }
        let mut descriptors = grant.descriptors();
        descriptors.push(child_lifetime.as_raw_fd());
        // SAFETY: the fork callback performs only async-signal-safe fcntl calls. It changes
        // child descriptors only; no parent-wide CLOEXEC race leaks locks to unrelated execs.
        unsafe {
            command.pre_exec(move || {
                for fd in &descriptors {
                    if libc::fcntl(*fd, libc::F_SETFD, 0) == -1 {
                        return Err(std::io::Error::last_os_error());
                    }
                }
                Ok(())
            });
        }
        let child =
            command.spawn().map_err(|_| RecoveryCommandError::Runtime("spawn owned component"))?;
        state.children.push(OwnedChild { role, child, lifetime });
        Ok(())
    }
    /// Stop/reap lander, supervisor/Comet, then app. Cancellation cannot drop the leases
    /// out from under this cleanup: the blocking task owns the entire state until finished.
    pub async fn stop(&mut self) -> Result<(), RecoveryCommandError> {
        let state = Arc::clone(&self.state);
        tokio::task::spawn_blocking(move || cleanup(&state))
            .await
            .map_err(|_| RecoveryCommandError::Runtime("owned cleanup task"))?
    }
}
impl Drop for OwnedRuntime {
    /// Preserve ordered cleanup on cancellation, including outside an async runtime.
    fn drop(&mut self) {
        let state = Arc::clone(&self.state);
        // Even if descendants are uncertain, cleanup never skips to stopping later roles.
        let _ = std::thread::Builder::new().name("etna-owned-stop".into()).spawn(move || {
            let _ = cleanup(&state);
        });
    }
}
impl RuntimeState {
    /// Synchronous cleanup also runs after its async caller is cancelled.
    fn stop(&mut self) -> Result<(), RecoveryCommandError> {
        self.children.sort_by_key(|child| match child.role {
            ComponentRole::Lander => 0,
            ComponentRole::Supervisor | ComponentRole::Comet => 1,
            ComponentRole::App => 2,
        });
        for owned in &mut self.children {
            stop_child(&mut owned.child, Duration::from_secs(20))?;
            wait_descendants(&mut owned.lifetime)?;
        }
        Ok(())
    }
}
/// Serialize cleanup and release leases only after every owned process tree is quiescent.
fn cleanup(shared: &Mutex<Option<RuntimeState>>) -> Result<(), RecoveryCommandError> {
    let mut guard = shared.lock().map_err(|_| RecoveryCommandError::Busy)?;
    if let Some(state) = guard.as_mut() {
        state.stop()?;
        guard.take();
    }
    Ok(())
}
/// A reaped supervisor alone is insufficient: its stock descendants must also close the
/// inherited endpoint. Unknown live descendants block app shutdown and remain operator-owned.
fn wait_descendants(lifetime: &mut UnixStream) -> Result<(), RecoveryCommandError> {
    let deadline = std::time::Instant::now() + Duration::from_secs(1);
    loop {
        match lifetime.read(&mut [0]) {
            Ok(0) => return Ok(()),
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {}
            _ => return Err(RecoveryCommandError::Busy),
        }
        if std::time::Instant::now() >= deadline {
            return Err(RecoveryCommandError::Busy);
        }
        std::thread::sleep(Duration::from_millis(20));
    }
}
/// Terminate only an unreaped retained handle; a reaped or reused PID is never signaled.
fn stop_child(child: &mut Child, grace: Duration) -> Result<(), RecoveryCommandError> {
    if child.try_wait().map_err(|_| RecoveryCommandError::Runtime("observe owned child"))?.is_some()
    {
        return Ok(());
    }
    if let Some(pid) = child.id() {
        // SAFETY: no other code owns/reaps this Child; its PID cannot be reused before wait.
        if unsafe { libc::kill(pid as libc::pid_t, libc::SIGTERM) } != 0 &&
            std::io::Error::last_os_error().raw_os_error() != Some(libc::ESRCH)
        {
            return Err(RecoveryCommandError::Runtime("terminate owned child"));
        }
    }
    if wait_child(child, grace)? {
        return Ok(());
    }
    child.start_kill().map_err(|_| RecoveryCommandError::Runtime("kill owned child"))?;
    if wait_child(child, Duration::from_secs(5))? {
        Ok(())
    } else {
        Err(RecoveryCommandError::Runtime(
            "owned child still unreaped; ownership retained by descendants",
        ))
    }
}
/// Bounded polling does not need a surviving Tokio executor during cancellation cleanup.
fn wait_child(child: &mut Child, timeout: Duration) -> Result<bool, RecoveryCommandError> {
    let deadline = std::time::Instant::now() + timeout;
    loop {
        if child
            .try_wait()
            .map_err(|_| RecoveryCommandError::Runtime("reap owned child"))?
            .is_some()
        {
            return Ok(true);
        }
        if std::time::Instant::now() >= deadline {
            return Ok(false);
        }
        std::thread::sleep(Duration::from_millis(20));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use abci::ownership::acquire_activation;
    use alloy_primitives::B256;
    use std::{collections::BTreeMap, path::Path};

    fn spec(root: &Path, role: ComponentRole) -> ProcessSpec {
        let directory = root.join(role.tag());
        std::fs::create_dir_all(&directory).unwrap();
        ProcessSpec {
            executable: Executable {
                program: "/usr/bin/python3".into(),
                argv: vec!["-c".into(), "import os,signal,sys,time\nfrom pathlib import Path\nr=Path(sys.argv[1]); role=sys.argv[2]\ndef stop(*_):\n with (r/'order').open('a') as f: f.write(role+'\\n')\n sys.exit(0)\nsignal.signal(signal.SIGTERM,stop)\n(r/(role+'.ready')).touch()\nwhile not (r/'release').exists(): time.sleep(.02)".into(), root.to_string_lossy().into(), role.tag().into()],
                env: BTreeMap::new(),
            },
            paths: ComponentPaths::new(role, &directory).unwrap(),
            cwd: directory,
        }
    }
    async fn until(mut predicate: impl FnMut() -> bool) {
        for _ in 0..250 {
            if predicate() {
                return;
            }
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
        assert!(predicate(), "process state did not converge");
    }
    #[tokio::test]
    async fn recovery_owned_controller_fixture() {
        let Ok(root) = std::env::var("ETNA_TASK8_TEST_ROOT") else {
            return;
        };
        let root = Path::new(&root);
        let mut runtime = OwnedRuntime::new(acquire_activation(root, B256::ZERO).unwrap());
        if std::env::var_os("ETNA_TASK8_CONTAINER_TEST").is_some() {
            let supervisor = spec(root, ComponentRole::Supervisor);
            runtime.fence(&supervisor.paths).unwrap();
            let result = runtime.spawn(ComponentRole::Supervisor, &supervisor);
            runtime.stop().await.unwrap();
            assert!(result.is_err(), "inherited Docker adapter must be rejected");
            return;
        }
        if std::env::var_os("ETNA_TASK8_INTERRUPT_TEST").is_some() {
            let mut interrupt =
                tokio::signal::unix::signal(tokio::signal::unix::SignalKind::interrupt()).unwrap();
            let children = [ComponentRole::App, ComponentRole::Comet, ComponentRole::Lander]
                .map(|role| spec(root, role));
            for child in &children {
                runtime.fence(&child.paths).unwrap();
            }
            for child in &children {
                runtime.spawn(child.paths.role, child).unwrap();
            }
            interrupt.recv().await;
            runtime.stop().await.unwrap();
            return;
        }
        let old = root.join("original-lander");
        std::fs::create_dir(&old).unwrap();
        runtime.fence(&ComponentPaths::new(ComponentRole::Lander, &old).unwrap()).unwrap();
        let child = spec(root, ComponentRole::App);
        runtime.fence(&child.paths).unwrap();
        runtime.spawn(ComponentRole::App, &child).unwrap();
        // The parent kills this controller after the actual child signals readiness.
        tokio::time::sleep(Duration::from_secs(60)).await;
        runtime.stop().await.unwrap();
    }
    #[tokio::test]
    async fn recovery_controller_group_sigint_preserves_ordered_cleanup() {
        let root = tempfile::tempdir().unwrap();
        let mut controller = Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "recovery::process::tests::recovery_owned_controller_fixture"])
            .env("ETNA_TASK8_TEST_ROOT", root.path())
            .env("ETNA_TASK8_INTERRUPT_TEST", "1")
            .process_group(0)
            .kill_on_drop(true)
            .stderr(std::process::Stdio::null())
            .spawn()
            .unwrap();
        until(|| {
            ["app", "comet", "lander"]
                .iter()
                .all(|role| root.path().join(format!("{role}.ready")).exists())
        })
        .await;
        let group = controller.id().unwrap() as libc::pid_t;
        assert_eq!(unsafe { libc::kill(-group, libc::SIGINT) }, 0);
        assert!(controller.wait().await.unwrap().success());
        assert_eq!(
            std::fs::read_to_string(root.path().join("order")).unwrap_or_default(),
            "lander\ncomet\napp\n"
        );
    }
    #[tokio::test]
    async fn recovery_local_owner_refuses_configured_or_inherited_container_adapter() {
        let root = tempfile::tempdir().unwrap();
        let mut runtime = OwnedRuntime::new(acquire_activation(root.path(), B256::ZERO).unwrap());
        let mut supervisor = spec(root.path(), ComponentRole::Supervisor);
        supervisor
            .executable
            .env
            .insert("ETNA_COMET_CONTAINER".into(), "external-container".into());
        runtime.fence(&supervisor.paths).unwrap();
        let result = runtime.spawn(ComponentRole::Supervisor, &supervisor);
        runtime.stop().await.unwrap();
        assert!(result.is_err(), "configured Docker adapter must be rejected");
        let status = Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "recovery::process::tests::recovery_owned_controller_fixture"])
            .env("ETNA_TASK8_TEST_ROOT", root.path())
            .env("ETNA_TASK8_CONTAINER_TEST", "1")
            .env("ETNA_COMET_CONTAINER", "external-container")
            .status()
            .await
            .unwrap();
        assert!(status.success());
    }
    #[tokio::test]
    async fn recovery_sigkill_controller_keeps_surviving_child_busy() {
        let root = tempfile::tempdir().unwrap();
        let mut controller = Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "recovery::process::tests::recovery_owned_controller_fixture"])
            .env("ETNA_TASK8_TEST_ROOT", root.path())
            .kill_on_drop(true)
            .spawn()
            .unwrap();
        until(|| root.path().join("app.ready").exists()).await;
        assert!(acquire_activation(root.path(), B256::ZERO).is_err());
        controller.kill().await.unwrap();
        assert!(acquire_activation(root.path(), B256::repeat_byte(1)).is_err());
        let app = ComponentPaths::new(ComponentRole::App, &root.path().join("app")).unwrap();
        assert!(ComponentLease::acquire(&app, None).is_err());
        let old = ComponentPaths::new(ComponentRole::Lander, &root.path().join("original-lander"))
            .unwrap();
        assert!(ComponentLease::acquire(&old, None).is_err());
        std::fs::write(root.path().join("release"), b"").unwrap();
        until(|| acquire_activation(root.path(), B256::ZERO).is_ok()).await;
        assert!(ComponentLease::acquire(&app, None).is_ok());
    }
    #[tokio::test]
    async fn recovery_owned_stop_orders_children_and_releases_descriptors() {
        let root = tempfile::tempdir().unwrap();
        let mut runtime = OwnedRuntime::new(acquire_activation(root.path(), B256::ZERO).unwrap());
        let specs = [ComponentRole::App, ComponentRole::Comet, ComponentRole::Lander]
            .map(|role| spec(root.path(), role));
        for spec in &specs {
            runtime.fence(&spec.paths).unwrap();
        }
        for spec in &specs {
            runtime.spawn(spec.paths.role, spec).unwrap();
            assert!(runtime.spawn(spec.paths.role, spec).is_err());
            until(|| root.path().join(format!("{}.ready", spec.paths.role.tag())).exists()).await;
        }
        runtime.stop().await.unwrap();
        assert_eq!(
            std::fs::read_to_string(root.path().join("order")).unwrap(),
            "lander\ncomet\napp\n"
        );
        assert!(acquire_activation(root.path(), B256::ZERO).is_ok());
        for spec in &specs {
            assert!(ComponentLease::acquire(&spec.paths, None).is_ok());
        }
        runtime.stop().await.unwrap();
    }
    #[tokio::test]
    async fn recovery_cancelled_owner_still_reaps_its_child() {
        let root = tempfile::tempdir().unwrap();
        let mut runtime = OwnedRuntime::new(acquire_activation(root.path(), B256::ZERO).unwrap());
        let spec = spec(root.path(), ComponentRole::App);
        runtime.fence(&spec.paths).unwrap();
        runtime.spawn(ComponentRole::App, &spec).unwrap();
        until(|| root.path().join("app.ready").exists()).await;
        drop(runtime);
        until(|| acquire_activation(root.path(), B256::ZERO).is_ok()).await;
        assert_eq!(std::fs::read_to_string(root.path().join("order")).unwrap(), "app\n");
    }
    #[tokio::test]
    async fn recovery_live_descendant_blocks_app_stop_until_eof() {
        let root = tempfile::tempdir().unwrap();
        let mut runtime = OwnedRuntime::new(acquire_activation(root.path(), B256::ZERO).unwrap());
        let app = spec(root.path(), ComponentRole::App);
        let mut supervisor = spec(root.path(), ComponentRole::Supervisor);
        supervisor.executable.argv[1] = "import os,sys,time\nfrom pathlib import Path\nr=Path(sys.argv[1])\nif os.fork(): sys.exit(0)\n(r/'supervisor.ready').touch()\nwhile not (r/'release-descendant').exists(): time.sleep(.02)".into();
        runtime.fence(&app.paths).unwrap();
        runtime.fence(&supervisor.paths).unwrap();
        runtime.spawn(ComponentRole::App, &app).unwrap();
        runtime.spawn(ComponentRole::Supervisor, &supervisor).unwrap();
        until(|| {
            root.path().join("app.ready").exists() && root.path().join("supervisor.ready").exists()
        })
        .await;
        let stopped = runtime.stop().await;
        let app_was_stopped = root.path().join("order").exists();
        std::fs::write(root.path().join("release-descendant"), b"").unwrap();
        assert!(stopped.is_err(), "live supervisor descendant must be Busy");
        assert!(!app_was_stopped, "app stopped while Comet descendant still held liveness");
        runtime.stop().await.unwrap();
        assert_eq!(std::fs::read_to_string(root.path().join("order")).unwrap(), "app\n");
        assert!(acquire_activation(root.path(), B256::ZERO).is_ok());
    }
    #[tokio::test]
    async fn recovery_cancelled_stop_future_keeps_cleanup_and_leases_alive() {
        let root = tempfile::tempdir().unwrap();
        let mut runtime = OwnedRuntime::new(acquire_activation(root.path(), B256::ZERO).unwrap());
        let mut child = spec(root.path(), ComponentRole::App);
        child.executable.argv[1] =
            child.executable.argv[1].replace("def stop(*_):\n", "def stop(*_):\n time.sleep(.2)\n");
        runtime.fence(&child.paths).unwrap();
        runtime.spawn(ComponentRole::App, &child).unwrap();
        until(|| root.path().join("app.ready").exists()).await;
        assert!(tokio::time::timeout(Duration::from_millis(20), runtime.stop()).await.is_err());
        assert!(acquire_activation(root.path(), B256::ZERO).is_err());
        until(|| acquire_activation(root.path(), B256::ZERO).is_ok()).await;
        assert_eq!(std::fs::read_to_string(root.path().join("order")).unwrap(), "app\n");
        runtime.stop().await.unwrap();
    }
    #[tokio::test]
    async fn recovery_unresponsive_owned_child_is_killed_and_reaped() {
        use std::os::unix::process::ExitStatusExt;
        use tokio::io::AsyncBufReadExt;
        let mut child = Command::new("/usr/bin/python3").args(["-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('ready',flush=True); time.sleep(60)"])
            .stdout(std::process::Stdio::piped()).kill_on_drop(true).spawn().unwrap();
        let mut output = tokio::io::BufReader::new(child.stdout.take().unwrap()).lines();
        assert_eq!(output.next_line().await.unwrap().as_deref(), Some("ready"));
        stop_child(&mut child, Duration::from_millis(20)).unwrap();
        assert_eq!(child.try_wait().unwrap().unwrap().signal(), Some(libc::SIGKILL));
        assert_eq!(child.id(), None);
    }
    #[tokio::test]
    async fn recovery_reaped_handle_never_signals_a_foreign_process() {
        let mut exited = Command::new("/usr/bin/true").spawn().unwrap();
        exited.wait().await.unwrap();
        let mut foreign = Command::new("/bin/sleep").arg("10").kill_on_drop(true).spawn().unwrap();
        assert_eq!(exited.id(), None);
        stop_child(&mut exited, Duration::from_millis(20)).unwrap();
        assert!(foreign.try_wait().unwrap().is_none());
        foreign.kill().await.unwrap();
    }
}
