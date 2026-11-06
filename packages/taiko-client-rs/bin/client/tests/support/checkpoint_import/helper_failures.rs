//! Exercise the official native helpers across the public controller's real process boundary.
use super::*;

/// Damage only fresh disposable copies. The original donor and selected landing stay identical
/// so both negative cases reach the native leaf/code verifier with the same trusted root.
pub(super) async fn code_preimages(
    base: &Path,
    profile: &Path,
    package: &Path,
    source: &Path,
    stopped_donor: &Path,
) -> Result<()> {
    let mut config: Value = serde_json::from_slice(&fs::read(profile)?)?;
    let chain = PathBuf::from(config["install"]["el_chain"].as_str().context("EL chain")?);
    let runtime = PathBuf::from(config["install"]["el_binary"].as_str().context("EL binary")?);
    let genesis: Value = serde_json::from_slice(&fs::read(&chain)?)?;
    let system = genesis["alloc"][format!("{:#x}", test_harness::genesis::ROOTS)]["code"]
        .as_str()
        .context("EIP-4788 runtime")?;
    let code = alloy_primitives::hex::decode(system.trim_start_matches("0x"))?;
    ensure!(code.len() > 32);
    for missing in [true, false] {
        let name = if missing { "missing-code" } else { "wrong-code" };
        let db = base.join(name).join("db");
        fs::create_dir_all(&db)?;
        for file in ["database.version", "mdbx.dat"] {
            fs::copy(source.join("db").join(file), db.join(file))?;
        }
        if missing {
            // Stock's table operation recomputes MDBX pages; only the bytecode preimages
            // disappear. Accounts keep all of their original authenticated code hashes.
            let editable = base.join("code-table-control");
            fs::rename(db.parent().unwrap(), &editable)?;
            // Reth's DB command opens a full provider before clearing a table and checks
            // its existing stage checkpoints against the matching static-file segments.
            for tree in ["static_files", "rocksdb"] {
                let copied = std::process::Command::new("cp")
                    .arg("-R")
                    .arg(stopped_donor.join(tree))
                    .arg(editable.join(tree))
                    .output()?;
                ensure!(
                    copied.status.success(),
                    "copy stopped native fixture history: {}",
                    String::from_utf8_lossy(&copied.stderr)
                );
            }
            // Only the native node subcommand accepts --devnet-etna-timestamp. Give the DB
            // maintenance command the equivalent block-zero Ethereum forks so it recognizes
            // the copied original genesis; the real import continues using its original chain.
            let mut db_genesis = genesis.clone();
            for fork in ["cancunTime", "pragueTime", "osakaTime"] {
                db_genesis["config"][fork] = json!(0);
            }
            let db_chain = base.join("code-table-chain.json");
            write_private(&db_chain, serde_json::to_vec(&db_genesis)?)?;
            let out = std::process::Command::new(&runtime)
                .arg("db")
                .arg("--chain")
                .arg(&db_chain)
                .arg("--datadir")
                .arg(&editable)
                .args(["--db.growth-step", "4MB", "clear", "mdbx", "Bytecodes"])
                .output()?;
            ensure!(
                out.status.success(),
                "clear disposable code table: {}",
                String::from_utf8_lossy(&out.stderr)
            );
            // Never inherit/remove a source node's lock. Reopen a new physically independent copy.
            fs::create_dir_all(&db)?;
            for file in ["database.version", "mdbx.dat"] {
                fs::copy(editable.join("db").join(file), db.join(file))?;
            }
        } else {
            // Flip a byte in the known real EIP-4788 preimage, preserving the native compact
            // row length, code-hash key and account trie leaves. Include old MDBX copies too.
            let data = db.join("mdbx.dat");
            let mut bytes = fs::read(&data)?;
            let offsets: Vec<_> = bytes
                .windows(code.len())
                .enumerate()
                .filter_map(|(i, w)| (w == code).then_some(i))
                .collect();
            ensure!(!offsets.is_empty(), "native source must store EIP-4788 bytes");
            for offset in offsets {
                bytes[offset] ^= 1;
            }
            fs::write(&data, bytes)?;
        }
        config["install"]["el_source"] = json!(db.parent().unwrap());
        let subprofile = base.join(format!("{name}.json"));
        write_private(&subprofile, serde_json::to_vec(&config)?)?;
        let root = base.join(format!("{name}-operation"));
        let out = std::process::Command::new(CLIENT)
            .args(["abci-import", "prepare", "--profile"])
            .arg(&subprofile)
            .arg("--root")
            .arg(&root)
            .arg("--package")
            .arg(package)
            .output()?;
        let msg = String::from_utf8_lossy(&out.stderr);
        let diag = fs::read_to_string(root.join(".checkpoint-work/el-verify.stderr"))?;
        let (class, reason) = if missing {
            ("checkpoint material unavailable", "missing referenced bytecode")
        } else {
            ("invalid checkpoint candidate", "bytecode content does not match its hash")
        };
        ensure!(
            out.status.code() == Some(1) && msg.contains(class) && diag.contains(reason),
            "{name}: {msg}; {diag}"
        );
        ensure!(!root.join("ready").exists() && !root.join("halted.json").exists());
        eprintln!("checkpoint_helper_control={name} class={class} published=false latched=false");
    }
    Ok(())
}

/// A healthy signed package reaches stock install. Reserve the fresh private output name between
/// prepare and the helper's mkdir to produce a real, repairable storage failure.
pub(super) async fn occupied_stock_output(base: &Path, root: &Path, profile: &str) -> Result<()> {
    use std::process::Stdio;
    let mut child = tokio::process::Command::new(CLIENT)
        .args(["abci-import", "install", "--profile", profile, "--root"])
        .arg(root)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()?;
    let work = root.join(".checkpoint-work");
    tokio::time::timeout(Duration::from_secs(30), async {
        while !work.join("stock.json").is_file() {
            ensure!(child.try_wait()?.is_none(), "controller exited before native storage fault");
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        fs::create_dir(work.join("comet"))?;
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    let out = child.wait_with_output().await?;
    let msg = String::from_utf8_lossy(&out.stderr);
    ensure!(
        out.status.code() == Some(1) && msg.contains("checkpoint material unavailable"),
        "unexpected stock-storage class: {msg}"
    );
    ensure!(
        work.join("stock.install.stderr").is_file() &&
            !root.join("halted.json").exists() &&
            !root.join("ready").exists()
    );
    let v = cli(base, "storage-incomplete-status", &["status", "--root", root.to_str().unwrap()])
        .await?;
    ensure!(v["phase"] == "staging" && v["live_trust"] == false);
    Ok(())
}
