//! The docker CLI: one private network and the containers started on it, removed on drop.

use std::process::{Command, Output};

use anyhow::{Context, Result, bail};

/// Runs `docker <args>` and returns its trimmed stdout; a non-zero exit is an error carrying
/// stderr.
pub(crate) async fn docker(args: &[&str]) -> Result<String> {
    let output = tokio::process::Command::new("docker")
        .args(args)
        .output()
        .await
        .with_context(|| format!("spawning docker {}", args.join(" ")))?;
    check(args, output)
}

/// Blocking [`docker`], for `Drop`.
pub(crate) fn docker_blocking(args: &[&str]) -> Result<String> {
    let output = Command::new("docker")
        .args(args)
        .output()
        .with_context(|| format!("spawning docker {}", args.join(" ")))?;
    check(args, output)
}

/// The trimmed stdout of a successful `output`, or an error naming `args` and carrying stderr.
fn check(args: &[&str], output: Output) -> Result<String> {
    if !output.status.success() {
        bail!(
            "docker {} failed ({}): {}",
            args.join(" "),
            output.status,
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// The host port docker published for `container_port/tcp` of `container`.
pub(crate) async fn host_port(container: &str, container_port: u16) -> Result<u16> {
    let out = docker(&["port", container, &format!("{container_port}/tcp")]).await?;
    // One line per address family, e.g. `0.0.0.0:55001` and `[::]:55001`.
    out.lines()
        .find_map(|line| line.rsplit_once(':').and_then(|(_, port)| port.trim().parse().ok()))
        .with_context(|| format!("no host port for {container}:{container_port} in {out:?}"))
}

/// One devnet's docker resources: a private network and the containers started on it.
///
/// Dropping it without [`DockerEnv::cleanup`] removes everything (blocking) and, while
/// panicking, first prints the tail of every container's log.
#[derive(Debug)]
pub(crate) struct DockerEnv {
    /// The network name.
    network: String,
    /// Names of the containers started on it, in start order.
    containers: Vec<String>,
    /// Whether the network exists.
    network_created: bool,
    /// Whether everything was already removed.
    cleaned: bool,
}

impl DockerEnv {
    /// Creates the network `name`.
    pub(crate) async fn create(name: String) -> Result<Self> {
        let mut env =
            Self { network: name, containers: Vec::new(), network_created: false, cleaned: false };
        docker(&["network", "create", &env.network]).await?;
        env.network_created = true;
        Ok(env)
    }

    /// The network name.
    pub(crate) fn network(&self) -> &str {
        &self.network
    }

    /// `docker run -d --name <name> --network <network> <args…>`; the container is removed with
    /// the environment even when `run` fails.
    pub(crate) async fn run(&mut self, name: &str, args: &[&str]) -> Result<()> {
        self.containers.push(name.to_string());
        let mut full = vec!["run", "-d", "--name", name, "--network", &self.network];
        full.extend_from_slice(args);
        docker(&full).await.map(drop)
    }

    /// Prints `docker logs --tail 200` of every container to stderr.
    pub(crate) fn dump_logs(&self) {
        for name in &self.containers {
            eprintln!("===== docker logs --tail 200 {name} =====");
            match Command::new("docker").args(["logs", "--tail", "200", name]).output() {
                Ok(out) => {
                    eprintln!("{}", String::from_utf8_lossy(&out.stdout));
                    eprintln!("{}", String::from_utf8_lossy(&out.stderr));
                }
                Err(e) => eprintln!("(cannot read logs: {e})"),
            }
        }
    }

    /// Removes every container and the network.
    pub(crate) async fn cleanup(&mut self) -> Result<()> {
        if self.cleaned {
            return Ok(());
        }
        self.cleaned = true;
        if !self.containers.is_empty() {
            let mut args = vec!["rm", "-f", "-v"];
            args.extend(self.containers.iter().map(String::as_str));
            docker(&args).await?;
        }
        if self.network_created {
            docker(&["network", "rm", &self.network]).await?;
        }
        Ok(())
    }

    /// Blocking [`DockerEnv::cleanup`]; failures are printed.
    fn cleanup_blocking(&mut self) {
        if self.cleaned {
            return;
        }
        self.cleaned = true;
        if !self.containers.is_empty() {
            let mut args = vec!["rm", "-f", "-v"];
            args.extend(self.containers.iter().map(String::as_str));
            if let Err(e) = docker_blocking(&args) {
                eprintln!("devnet cleanup: {e:#}");
            }
        }
        if self.network_created &&
            let Err(e) = docker_blocking(&["network", "rm", &self.network])
        {
            eprintln!("devnet cleanup: {e:#}");
        }
    }
}

impl Drop for DockerEnv {
    /// Removes what is left, printing the container logs first while panicking.
    fn drop(&mut self) {
        if self.cleaned {
            return;
        }
        if std::thread::panicking() {
            self.dump_logs();
        }
        self.cleanup_blocking();
    }
}
