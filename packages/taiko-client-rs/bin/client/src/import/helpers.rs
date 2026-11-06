//! Pinned native subprocesses with inherited leases and bounded receipts. No shell or PID adoption.
use super::*;
use abci::ownership::{ComponentLease, ComponentPaths, ComponentRole, OwnerGrant};
use alloy_consensus::Header;
use std::{
    io::{Read, Seek, SeekFrom},
    os::unix::process::CommandExt,
    process::{Child, Command, Stdio},
    time::Duration,
};

/// All leases are inherited even by a helper which needs only one component.
pub(super) struct Holds {
    /// Duplicated, same-open-description reservation barrier, including activation.
    grant: OwnerGrant,
}
impl Holds {
    /// Reserve components before starting any writer. A private Comet placeholder is removed
    /// after acquiring its sibling lease because stock Install requires a nonexistent home.
    pub(super) fn acquire(
        a: &ActivationLease,
        dir: &Path,
        mut leases: Vec<ComponentLease>,
    ) -> R<Self> {
        for (name, role) in [
            ("app", ComponentRole::App),
            ("comet", ComponentRole::Comet),
            ("el", ComponentRole::Execution),
        ] {
            let p = dir.join(name);
            files::mkdir(&p)?;
            leases.push(
                ComponentLease::acquire(&ComponentPaths::new(role, &p).map_err(bad)?, None)
                    .map_err(bad)?,
            );
            if name == "comet" {
                fs::remove_dir(&p).map_err(io)?
            }
        }
        Ok(Self { grant: OwnerGrant::for_child(a, &leases, 0).map_err(bad)? })
    }
    /// Fence the exact app and execution writers before launching an installed node. The
    /// independent stock launcher reserves Comet immediately before opening its databases.
    pub(super) fn installed(root: &Path, ready: &Path, id: B256) -> R<Self> {
        let activation = acquire_activation(root, id).map_err(bad)?;
        let mut leases = Vec::new();
        for (role, path) in
            [(ComponentRole::App, ready.join("app")), (ComponentRole::Execution, ready.join("el"))]
        {
            leases.push(
                ComponentLease::acquire(&ComponentPaths::new(role, &path).map_err(bad)?, None)
                    .map_err(bad)?,
            );
        }
        Ok(Self { grant: OwnerGrant::for_child(&activation, &leases, 0).map_err(bad)? })
    }
    /// Pass only hold descriptors, not a runtime join token, to stock children.
    pub(super) fn command(&self, binary: &Path) -> R<Command> {
        files::file(binary)?;
        let mut cmd = Command::new(std::env::current_exe().map_err(io)?);
        cmd.arg(super::guardian::ARG).arg(binary);
        cmd.env_clear()
            .env_remove(abci::ownership::OWNER_FDS_ENV)
            .env_remove(abci::ownership::OWNER_JOIN_ENV)
            .stdin(Stdio::piped())
            .process_group(0);
        let fds = self.grant.descriptors();
        // SAFETY: only async-signal-safe fcntl is called in the fork child.
        unsafe {
            cmd.pre_exec(move || {
                for fd in &fds {
                    if libc::fcntl(*fd, libc::F_SETFD, 0) < 0 {
                        return Err(std::io::Error::last_os_error())
                    }
                }
                Ok(())
            })
        };
        Ok(cmd)
    }
}
/// A separate guard owns the normal execution process. Closing its lifetime pipe allows
/// it to reap the EL even after an abrupt controller exit.
pub(super) struct Guarded(pub(super) Child);
impl Drop for Guarded {
    /// Closing the controller's last writer is the shutdown request; wait for real cleanup.
    fn drop(&mut self) {
        self.0.stdin.take();
        let _ = self.0.wait();
    }
}
/// Typed authenticated contradiction. Ordinary Go crashes can also exit two.
#[derive(Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct Contradiction {
    /// Supported receipt version.
    schema: u32,
    /// Native verifier classification.
    kind: String,
    /// Exact independently authenticated conflicting fact.
    reason: String,
    /// Verified terminal height.
    height: u64,
    /// Trusted landed consensus hash.
    comet_hash: B256,
    /// Trusted landed execution hash.
    el_hash: B256,
    /// Trusted canonical priority commitment.
    val_state_hash: B256,
    /// Digest of the exact bytes supplied to Go.
    package_hash: B256,
}
/// Match every trusted binding, checking the machine receipt only on the registered exit code.
fn result_bytes(
    status: std::process::ExitStatus,
    bytes: &[u8],
    expected: Option<&Contradiction>,
) -> R<Value> {
    if status.success() {
        return serde_json::from_slice(bytes).map_err(|_| bad("invalid helper receipt"))
    }
    if status.code() == Some(2) &&
        let Some(expected) = expected &&
        serde_json::from_slice::<Contradiction>(bytes).ok().as_ref() == Some(expected)
    {
        return Err(ImportError::Safety(
            "stock verifier: landed future validators contradict authenticated terminal header"
                .into(),
        ))
    }
    if status.code() == Some(1) {
        return Err(bad("native helper rejected input; inspect its private staging diagnostic"))
    }
    Err(ImportError::Unavailable(
        "native verifier terminated without a bound contradiction receipt".into(),
    ))
}
/// Run a verifier in the retained guardian. Bound stdout before parsing any verdict.
async fn receipt(
    mut command: Command,
    expected: Option<&Contradiction>,
    diagnostics: &Path,
) -> R<Value> {
    let mut output = tempfile::tempfile().map_err(io)?;
    command.stdout(output.try_clone().map_err(io)?).stderr(files::create(diagnostics)?);
    let mut child = Guarded(command.spawn().map_err(io)?);
    let status = loop {
        if output.metadata().map_err(io)?.len() > 1 << 20 {
            return Err(bad("helper output exceeds bound"))
        }
        if let Some(status) = child.0.try_wait().map_err(io)? {
            break status
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    };
    output.seek(SeekFrom::Start(0)).map_err(io)?;
    let mut bytes = Vec::new();
    output.take((1 << 20) + 1).read_to_end(&mut bytes).map_err(io)?;
    if bytes.len() > 1 << 20 {
        return Err(bad("helper receipt too large"))
    }
    let value = result_bytes(status, &bytes, expected)?;
    fs::remove_file(diagnostics).map_err(io)?;
    Ok(value)
}
/// Compare all external stock report facts, including full part-set identity and both future sets.
pub(super) async fn comet(
    binary: &Path,
    stock: &Path,
    package_hash: B256,
    home: Option<&Path>,
    v: &VerifiedImport,
    holds: &Holds,
) -> R<B256> {
    let l = v.landing();
    let mut cmd = holds.command(binary)?;
    cmd.arg(if home.is_some() { "install" } else { "verify" })
        .arg("--package")
        .arg(stock)
        .arg("--trusted-comet-hash")
        .arg(l.comet_hash.to_string())
        .arg("--trusted-el-hash")
        .arg(l.el_hash.to_string())
        .arg("--trusted-val-state-hash")
        .arg(l.val_state_hash.to_string());
    if let Some(home) = home {
        cmd.arg("--home").arg(home);
    }
    let parent = stock.parent().ok_or_else(|| bad("stock package missing owned parent"))?;
    cmd.arg("--spool-parent").arg(parent).env("TMPDIR", parent);
    let expected_receipt = Contradiction {
        schema: 1,
        kind: "authenticated_contradiction".into(),
        reason: "validator_state_next_hash_mismatch".into(),
        height: l.height,
        comet_hash: l.comet_hash,
        el_hash: l.el_hash,
        val_state_hash: l.val_state_hash,
        package_hash,
    };
    let r = receipt(
        cmd,
        Some(&expected_receipt),
        &stock.with_extension(if home.is_some() { "install.stderr" } else { "verify.stderr" }),
    )
    .await?;
    let id = v.block_id().ok_or_else(|| bad("stock helper is not fixed genesis"))?;
    let hash = |h: tendermint::Hash| B256::try_from(h.as_bytes()).map_err(bad);
    let future = |set: &abci::valstate::ValSet| {
        abci::wire::validators_hash(
            &set.entries
                .iter()
                .map(|e| abci::Member {
                    pubkey: e.key,
                    power: e.power as u64,
                    eff_stake: U256::ZERO,
                })
                .collect::<Vec<_>>(),
        )
        .map_err(bad)
    };
    let time: tendermint::Time = serde_json::from_value(r["terminal_time"].clone())
        .map_err(|_| bad("stock terminal time"))?;
    let package: B256 = serde_json::from_value(r["package_hash"].clone())
        .map_err(|_| bad("stock package digest"))?;
    let expected = json!({"schema":1,"first_height":v.first_height(),"last_height":l.height,"block_id":{"hash":hash(id.hash)?,"parts":{"total":id.part_set_header.total,"hash":hash(id.part_set_header.hash)?}},"terminal_time":r["terminal_time"],"chain_id":v.genesis().chain_id,"initial_height":v.state().origin_height()+1,"validators_hash":future(&v.state().val_state.current)?,"next_validators_hash":future(&v.state().val_state.next)?,"package_hash":package});
    if package != package_hash || r != expected || Some(time) != v.terminal_time() {
        return Err(bad("stock helper report disagrees with authenticated checkpoint"))
    }
    Ok(package)
}
/// Bind native LevelDB keys before publication, including the three genuinely empty stock stores
/// that fixed genesis will later initialize normally.
pub(super) async fn bind_stock(
    binary: &Path,
    home: &Path,
    id: B256,
    fixed_origin: bool,
    holds: &Holds,
) -> R<()> {
    files::put(
        &home.join(".etna-stock-staging.json"),
        &json!({"schema":1,"installation_id":id,"fixed_origin":fixed_origin}),
    )?;
    let mut cmd = holds.command(binary)?;
    cmd.arg("bind-stores").arg("--home").arg(home).arg("--installation-id").arg(id.to_string());
    if fixed_origin {
        cmd.arg("--fixed-origin");
    }
    if receipt(cmd, None, &home.join("identity.stderr")).await? != json!({}) {
        return Err(bad("stock store binding receipt"))
    }
    Ok(())
}
/// Preserve the serialization order of the independent pinned helper's header manifest.
#[derive(Serialize)]
pub(super) struct Manifest<'a> {
    /// Schema fixed by the helper contract.
    schema: u32,
    /// Local immutable plan identity.
    installation_id: B256,
    /// Runtime EL chain identity.
    chain_id: u64,
    /// Fixed current-generation origin, not a substitute for deployment genesis.
    origin: u64,
    /// Authenticated unsettled depth.
    unsettled_limit: u64,
    /// Inherited post-s checkpoint q.
    finalized_height: u64,
    /// Authenticated q hash used for post-install forkchoice.
    finalized_hash: B256,
    /// Contiguous actual linked header range.
    headers: &'a [Header],
}
impl<'a> Manifest<'a> {
    /// Bind q and origin exclusively from verified app facts.
    pub(super) fn new(id: B256, p: &abci::ChainParams, v: &'a VerifiedImport) -> R<Self> {
        // At fixed recovery genesis no block of this generation has yet inherited an
        // anchor. Its post-o fence comes from the R proof. AppState retains the OLD
        // parent's anchor only as historical input to RECOV-8.4, not its finality.
        let fixed;
        let anchor = if v.first_height().is_none() &&
            let Some(origin) = &v.state().recovery
        {
            fixed = abci::genesis::verify_original_genesis(v.genesis(), p).map_err(bad)?;
            if fixed.anchor.inbox.recovery_generation != origin.generation ||
                fixed.anchor.inbox.last_checkpoint_height != origin.height ||
                fixed.anchor.inbox.last_checkpoint_hash != origin.el_hash
            {
                return Err(ImportError::Safety(
                    "authenticated recovery R checkpoint contradicts fixed origin".into(),
                ))
            }
            &fixed.anchor
        } else {
            &v.state().anchor
        };
        Ok(Self {
            schema: 1,
            installation_id: id,
            chain_id: p.l2_chain_id,
            origin: v.state().origin_height(),
            unsettled_limit: p.unsettled_limit,
            finalized_height: anchor.inbox.last_checkpoint_height,
            finalized_hash: anchor.inbox.last_checkpoint_hash,
            headers: v.execution_headers(),
        })
    }
    /// Strict helper trust argv and receipt check for independent verification or installation.
    pub(super) async fn run(
        &self,
        i: &Installation,
        work: &Path,
        v: &VerifiedImport,
        holds: &Holds,
        install: bool,
    ) -> R<()> {
        let path = work.join("headers.json");
        let bytes = serde_json::to_vec(self).map_err(bad)?;
        if !files::exists(&path)? {
            files::write(&path, &bytes)?
        }
        if files::keccak_file(&path)? != keccak256(&bytes) {
            return Err(bad("header manifest changed"))
        }
        let el = work.join("el");
        let last = self.headers.last().ok_or_else(|| bad("missing terminal header"))?;
        if install {
            files::put(
                &el.join(".etna-el-import-staging.json"),
                &json!({"schema":1,"installation_id":self.installation_id,"manifest_hash":keccak256(&bytes)}),
            )?;
        }
        let mut cmd = holds.command(&i.el_helper)?;
        cmd.arg(if install { "install" } else { "verify" })
            .arg("--datadir")
            .arg(&el)
            .arg("--scratch-parent")
            .arg(work)
            .arg("--chain")
            .arg(&i.el_chain)
            .arg("--manifest")
            .arg(&path)
            .arg("--chain-id")
            .arg(self.chain_id.to_string())
            .arg("--trusted-el-hash")
            .arg(v.landing().el_hash.to_string())
            .arg("--trusted-state-root")
            .arg(last.state_root.to_string())
            .arg("--trusted-genesis-hash")
            .arg(v.state().genesis.genesis_hash.to_string());
        let r = receipt(
            cmd,
            None,
            &work.join(if install { "el-install.stderr" } else { "el-verify.stderr" }),
        )
        .await?;
        let state = &r["state"];
        if state["state_root"] != json!(last.state_root) ||
            ["accounts", "storage_slots", "bytecodes"]
                .iter()
                .any(|k| state[*k].as_u64().is_none()) ||
            state["storage_v2"].as_bool().is_none() ||
            state.as_object().is_none_or(|o| o.len() != 5)
        {
            return Err(bad("EL state verification report mismatch"))
        }
        let expected = json!({"schema":1,"installation_id":self.installation_id,"helper_version":"0.1.0","alethia_revision":"6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4","reth_revision":"d9bd9875fe88dcc0183d78b187ce2ceab0c93e93","manifest_hash":keccak256(bytes),"chain_id":self.chain_id,"genesis_hash":v.state().genesis.genesis_hash,"height":last.number,"block_hash":last.hash_slow(),"state_root":last.state_root,"finalized_height":self.finalized_height,"finalized_hash":self.finalized_hash,"first_header":self.headers[0].number,"last_header":last.number,"header_count":self.headers.len(),"state_floor":install.then_some(last.number),"installed":install,"state":state});
        if expected != r {
            return Err(bad("EL helper report disagrees with authenticated headers"))
        }
        files::put(&work.join(if install { "el-install.json" } else { "el-verify.json" }), &r)
    }
    /// Start the normal EL from the staged effective datadir with a fresh local JWT. Require
    /// exact head/q and a hash-pinned state read before orderly shutdown and publication.
    pub(super) async fn smoke(
        &self,
        i: &Installation,
        work: &Path,
        holds: &Holds,
        params: &abci::ChainParams,
        l1: &abci::RpcL1Source,
    ) -> R<()> {
        use abci::{Engine, engine::PayloadVerdict};
        let log = work.join("el-startup.log");
        let mut owned =
            super::runtime::OwnedEngine::start(i, &work.join("el"), holds, None, Some(&log))
                .await?;
        let engine = owned.engine.clone();
        let last = self.headers.last().ok_or_else(|| bad("missing terminal header"))?;
        if owned.chain_id().await? != U256::from(self.chain_id) ||
            engine.header_by_number(last.number).await.map_err(bad)?.as_ref() != Some(last) ||
            engine
                .forkchoice(last.hash_slow(), self.finalized_hash, self.finalized_hash)
                .await
                .map_err(bad)? !=
                PayloadVerdict::Valid ||
            engine
                .finalized_header()
                .await
                .map_err(bad)?
                .is_none_or(|h| h.hash_slow() != self.finalized_hash) ||
            !engine.historical_state_available(last.hash_slow()).await.map_err(bad)?
        {
            return Err(bad("normal EL rejected exact installed head/state/finality"))
        }
        if owned.exited()? {
            return Err(bad("normal EL exited before shutdown"))
        }
        let app = abci::App::new(
            l1.clone(),
            engine,
            params.clone(),
            abci::Store::imported(work.join("app"), self.installation_id, last.number),
            abci::AppOptions::default(),
        )
        .map_err(bad)?;
        if app
            .state()
            .is_none_or(|s| s.last_height != last.number || s.parent.hash != last.hash_slow())
        {
            return Err(bad("reopened app checkpoint baseline differs"))
        }
        owned.stop().await?;
        fs::remove_file(log).map_err(io)?;
        Ok(())
    }
}

#[cfg(test)]
mod contradiction_receipts {
    use super::*;
    use std::os::unix::process::ExitStatusExt;
    #[test]
    fn crash_is_unavailable_and_only_the_exact_proved_tuple_is_safety() {
        let expected = Contradiction {
            schema: 1,
            kind: "authenticated_contradiction".into(),
            reason: "validator_state_next_hash_mismatch".into(),
            height: 6,
            comet_hash: B256::repeat_byte(1),
            el_hash: B256::repeat_byte(2),
            val_state_hash: B256::repeat_byte(3),
            package_hash: B256::repeat_byte(4),
        };
        let exit = std::process::ExitStatus::from_raw(2 << 8);
        assert!(matches!(
            result_bytes(exit, b"", Some(&expected)),
            Err(ImportError::Unavailable(_))
        ));
        let valid = serde_json::to_value(&expected).unwrap();
        assert!(matches!(
            result_bytes(exit, &serde_json::to_vec(&valid).unwrap(), Some(&expected)),
            Err(ImportError::Safety(_))
        ));
        for key in [
            "schema",
            "kind",
            "reason",
            "height",
            "comet_hash",
            "el_hash",
            "val_state_hash",
            "package_hash",
            "extra",
        ] {
            let mut changed = valid.clone();
            changed[key] = Value::Null;
            assert!(
                matches!(
                    result_bytes(exit, &serde_json::to_vec(&changed).unwrap(), Some(&expected)),
                    Err(ImportError::Unavailable(_))
                ),
                "{key}"
            );
        }
        let mut other = valid;
        other["package_hash"] = json!(B256::repeat_byte(5));
        assert!(matches!(
            result_bytes(exit, &serde_json::to_vec(&other).unwrap(), Some(&expected)),
            Err(ImportError::Unavailable(_))
        ));
    }
}
