//! Owned real CLI processes with retained diagnostics and bounded shutdown.
use anyhow::{Context, Result, ensure};
use std::{
    fs::File,
    path::{Path, PathBuf},
    process::Stdio,
    time::Duration,
};
use tokio::process::{Child, Command};

pub struct Process {
    child: Child,
    log: PathBuf,
    remote: Option<(String, String)>,
}
impl Process {
    pub fn spawn(binary: &Path, args: &[String], log: PathBuf) -> Result<Self> {
        let output = File::create(&log)?;
        let child = Command::new(binary)
            .args(args)
            .env("RUST_LOG", "info")
            .env("METRICS_ENABLED", "false")
            .stdout(Stdio::from(output.try_clone()?))
            .stderr(Stdio::from(output))
            .stdin(Stdio::null())
            .kill_on_drop(true)
            .spawn()?;
        Ok(Self { child, log, remote: None })
    }
    pub fn in_container(container: &str, args: &[String], log: PathBuf) -> Result<Self> {
        let marker = format!("/fixture/{}.pid", log.file_stem().unwrap().to_string_lossy());
        let mut command = vec!["exec".into(), container.into(), "python3".into(), "-c".into(),
            "import os,sys; open(sys.argv[1],'w').write(str(os.getpid())); os.execv('/app/taiko-client',['/app/taiko-client']+sys.argv[2:])".into(), marker.clone()];
        command.extend_from_slice(args);
        let mut process = Self::spawn(Path::new("docker"), &command, log)?;
        process.remote = Some((container.into(), marker));
        Ok(process)
    }
    fn signal(&self) -> Result<()> {
        if let Some((container, marker)) = &self.remote {
            let result = std::process::Command::new("docker")
                .args([
                    "exec",
                    container,
                    "python3",
                    "-c",
                    "import os,signal,sys; os.kill(int(open(sys.argv[1]).read()),signal.SIGTERM)",
                    marker,
                ])
                .output()?;
            ensure!(
                result.status.success(),
                "owned container controller SIGTERM: {}",
                String::from_utf8_lossy(&result.stderr)
            );
        } else if let Some(id) = self.child.id() {
            // SAFETY: the retained child has not been reaped, so this PID cannot be reused.
            ensure!(unsafe { libc::kill(id as i32, libc::SIGTERM) } == 0, "owned SIGTERM");
        }
        Ok(())
    }
    pub fn running(&mut self) -> Result<()> {
        ensure!(self.child.try_wait()?.is_none(), "CLI exited: {}", self.output());
        Ok(())
    }
    pub fn output(&self) -> String {
        std::fs::read_to_string(&self.log).unwrap_or_default()
    }
    pub async fn stop(&mut self) -> Result<()> {
        if self.child.id().is_some() {
            self.signal()?;
        }
        let status = tokio::time::timeout(Duration::from_secs(40), self.child.wait()).await??;
        ensure!(status.success(), "unclean CLI exit: {}", self.output());
        Ok(())
    }
    pub async fn completed(&mut self) -> Result<String> {
        let status = tokio::time::timeout(Duration::from_secs(130), self.child.wait())
            .await
            .context("CLI command timeout")??;
        ensure!(status.success(), "CLI failed: {}", self.output());
        Ok(self.output())
    }
    pub async fn killed(&mut self) -> Result<()> {
        let status = tokio::time::timeout(Duration::from_secs(20), self.child.wait()).await??;
        ensure!(!status.success(), "SIGKILL must be an abrupt exit");
        Ok(())
    }
    pub async fn kill(&mut self) -> Result<()> {
        ensure!(self.remote.is_none(), "remote crashes must retain Linux pidfds before killing");
        self.child.start_kill()?;
        self.killed().await
    }
}
impl Drop for Process {
    fn drop(&mut self) {
        if self.child.id().is_some() {
            // Leave controller cleanup time before Tokio's kill-on-drop fallback.
            let _ = self.signal();
            let deadline = std::time::Instant::now() + Duration::from_secs(40);
            while self.child.try_wait().ok().flatten().is_none() &&
                std::time::Instant::now() < deadline
            {
                std::thread::sleep(Duration::from_millis(50));
            }
        }
    }
}
