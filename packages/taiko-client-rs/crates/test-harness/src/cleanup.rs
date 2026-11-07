//! Process-owned Docker resources and signal cleanup, independent of a test's tokio runtime.

use std::{
    collections::BTreeMap,
    sync::{Mutex, OnceLock},
};

use anyhow::{Result, anyhow};

use crate::docker::docker_blocking;

/// Networks and containers owned by this test process. Docker mutations hold this lock so a
/// signal cannot remove a resource just before an in-flight Docker command creates it.
pub(crate) fn resources() -> &'static Mutex<BTreeMap<String, Vec<String>>> {
    static RESOURCES: OnceLock<Mutex<BTreeMap<String, Vec<String>>>> = OnceLock::new();
    RESOURCES.get_or_init(Mutex::default)
}

/// Label shared by every child test in an entrypoint run, or scoped to this process when a
/// developer invokes cargo/nextest directly.
pub(crate) fn run_label() -> String {
    let owner = std::env::var("TAIKO_CLIENT_RS_TEST_RUN")
        .ok()
        .filter(|owner| !owner.is_empty())
        .unwrap_or_else(|| format!("process-{}", std::process::id()));
    format!("taiko-client-rs.test-run={owner}")
}

/// Install the process-wide signal listener once, before starting any Docker resource. Its
/// dedicated thread survives individual nextest test runtimes and exits unsuccessfully after
/// removing only resources registered by this process.
pub(crate) fn install() -> Result<()> {
    #[cfg(unix)]
    {
        static INSTALLED: OnceLock<std::result::Result<(), String>> = OnceLock::new();
        INSTALLED
            .get_or_init(|| {
                let (ready_tx, ready_rx) = std::sync::mpsc::sync_channel(1);
                std::thread::Builder::new()
                    .name("devnet-signal-cleanup".into())
                    .spawn(move || {
                        let setup = (|| {
                            let runtime = tokio::runtime::Builder::new_current_thread()
                                .enable_all()
                                .build()?;
                            let entered = runtime.enter();
                            let interrupt = tokio::signal::unix::signal(
                                tokio::signal::unix::SignalKind::interrupt(),
                            )?;
                            let terminate = tokio::signal::unix::signal(
                                tokio::signal::unix::SignalKind::terminate(),
                            )?;
                            drop(entered);
                            Ok::<_, std::io::Error>((runtime, interrupt, terminate))
                        })();
                        match setup {
                            Ok((runtime, mut interrupt, mut terminate)) => {
                                let _ = ready_tx.send(Ok(()));
                                let exit_code = runtime.block_on(async {
                                    tokio::select! {
                                        _ = interrupt.recv() => 130,
                                        _ = terminate.recv() => 143,
                                    }
                                });
                                let owned = resources().lock().unwrap();
                                for (network, containers) in owned.iter() {
                                    if !containers.is_empty() {
                                        let mut args = vec!["rm", "-f", "-v"];
                                        args.extend(containers.iter().map(String::as_str));
                                        if let Err(error) = docker_blocking(&args) {
                                            eprintln!("signal cleanup: {error:#}");
                                        }
                                    }
                                    if let Err(error) = docker_blocking(&["network", "rm", network])
                                    {
                                        eprintln!("signal cleanup: {error:#}");
                                    }
                                }
                                for (_, mut child) in
                                    std::mem::take(&mut *crate::signer::processes().lock().unwrap())
                                {
                                    let _ = child.kill();
                                    let _ = child.wait();
                                }
                                std::process::exit(exit_code);
                            }
                            Err(error) => {
                                let _ = ready_tx.send(Err(error.to_string()));
                            }
                        }
                    })
                    .map_err(|error| error.to_string())?;
                ready_rx.recv().map_err(|error| error.to_string())?
            })
            .as_ref()
            .map_err(|error| anyhow!("install test signal cleanup: {error}"))?;
    }
    Ok(())
}
