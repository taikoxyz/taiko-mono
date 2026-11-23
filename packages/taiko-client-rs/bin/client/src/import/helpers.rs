//! The two install helpers. Each install runs once, inherits the root lock, writes only its fresh
//! store under the stage and reports what it installed. The EL helper also derives the operator's
//! chain identity without opening stores; every receipt is checked before publication.
use super::*;
use alloy_consensus::Header;
use serde::Deserialize;
use std::process::Output;

/// Run a helper to completion and keep its output.
async fn run(mut command: tokio::process::Command, name: &str) -> R<Output> {
    command.output().await.map_err(|e| unavailable(format!("cannot run {name}: {:?}", e.kind())))
}

/// The stock helper's receipt (`etna-comet-import install`).
#[derive(Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
struct CometReport {
    /// First installed height, w + 1.
    first_height: u64,
    /// Last installed height, s.
    last_height: u64,
    /// The full stock BlockID of s.
    block_id: BlockId,
}

/// A stock BlockID: header hash and part-set header.
#[derive(Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
struct BlockId {
    /// Header hash.
    hash: B256,
    /// Canonical block part-set header.
    parts: Parts,
}

/// A stock part-set header.
#[derive(Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parts {
    /// Number of parts.
    total: u32,
    /// Merkle root of the parts.
    hash: B256,
}

/// The stock install report the authenticated window requires.
fn expected_comet(v: &VerifiedImport) -> R<CometReport> {
    let id = v.block_id().ok_or_else(|| bad("a fixed-origin import has no stock window"))?;
    let hash = |h: tendermint::Hash| B256::try_from(h.as_bytes()).map_err(bad);
    Ok(CometReport {
        first_height: v.first_height().ok_or_else(|| bad("missing first window height"))?,
        last_height: v.landing().height,
        block_id: BlockId {
            hash: hash(id.hash)?,
            parts: Parts { total: id.part_set_header.total, hash: hash(id.part_set_header.hash)? },
        },
    })
}

/// Accept the stock receipt only if it names exactly the authenticated window, whose terminal
/// header is the own-L1 landed Comet hash.
fn check_comet(stdout: &[u8], expected: &CometReport, comet_hash: B256) -> R<()> {
    let report: CometReport = serde_json::from_slice(stdout)
        .map_err(|_| unavailable("invalid etna-comet-import receipt"))?;
    if report != *expected || report.block_id.hash != comet_hash {
        return Err(unavailable(format!(
            "etna-comet-import installed {report:?}, not the authenticated window {expected:?}"
        )));
    }
    Ok(())
}

/// The `etna-comet-import install` arguments for s > o, with `app_hash` as `--app-hash`. The
/// genesis consensus params are the same fixed values for every deployment, so nothing else
/// selects them.
fn comet_install_args(home: &Path, stock: &Path, app_hash: B256) -> Vec<std::ffi::OsString> {
    vec![
        "install".into(),
        "--home".into(),
        home.into(),
        "--stock-dir".into(),
        stock.into(),
        "--app-hash".into(),
        app_hash.to_string().into(),
    ]
}

/// Install the stock Comet stores for s > o into the absent `home` from the stock dir
/// (DATA-5.4-3/4/5). The post-s AppHash is [`VerifiedImport::app_hash`], appHash(ELHash(s),
/// valStateHash(s)), the app hash the app's Info reports. Go checks nothing again: a nonzero
/// exit or a receipt that differs from the authenticated window is unavailable, never a latch.
pub(super) async fn comet_install(
    lock: &File,
    helper: &Path,
    home: &Path,
    stock: &Path,
    v: &VerifiedImport,
) -> R<()> {
    let expected = expected_comet(v)?;
    let mut command = helper_command(lock, helper);
    command.args(comet_install_args(home, stock, v.app_hash()));
    let output = run(command, "etna-comet-import").await?;
    if !output.status.success() {
        return Err(unavailable(format!(
            "etna-comet-import install failed ({}); see its stderr",
            output.status
        )));
    }
    check_comet(&output.stdout, &expected, v.landing().comet_hash)
}

/// The EL helper's header manifest (`etna-el-import install --manifest`), written by
/// [`lander::checkpoint_import::write_el_manifest`].
#[derive(Debug)]
pub(super) struct Manifest<'a> {
    /// Runtime EL chain id.
    chain_id: u64,
    /// The inherited post-s checkpoint q.
    finalized_height: u64,
    /// The authenticated hash at q, for the post-install forkchoice.
    finalized_hash: B256,
    /// The authenticated, parent-linked headers from the header floor through s.
    headers: &'a [Header],
}

impl<'a> Manifest<'a> {
    /// Take q and the headers only from the verified checkpoint.
    pub(super) fn new(p: &abci::ChainParams, v: &'a VerifiedImport) -> R<Self> {
        // At a fixed recovery origin no block of this generation has yet inherited an anchor.
        // Its post-o fence comes from the R proof. AppState retains the OLD parent's anchor only
        // as historical input to RECOV-8.4, not its finality.
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
                ));
            }
            &fixed.anchor
        } else {
            &v.state().anchor
        };
        Ok(Self {
            chain_id: p.l2_chain_id,
            finalized_height: anchor.inbox.last_checkpoint_height,
            finalized_hash: anchor.inbox.last_checkpoint_hash,
            headers: v.execution_headers(),
        })
    }

    /// Write the manifest to the new file `path`.
    fn write(&self, path: &Path) -> R<()> {
        lander::checkpoint_import::write_el_manifest(
            create(path)?,
            self.chain_id,
            self.finalized_height,
            self.finalized_hash,
            self.headers,
        )
        .map_err(io)
    }
}

/// The identity fields of the EL helper's receipt. Its other fields are informational.
#[derive(Debug, PartialEq, Eq, Deserialize)]
struct ElIdentity {
    /// Runtime EL chain id.
    chain_id: u64,
    /// Original EL genesis hash.
    genesis_hash: B256,
    /// The installed state height s.
    height: u64,
    /// ELHash(s).
    block_hash: B256,
    /// The state root of s, recomputed from the installed leaves.
    state_root: B256,
    /// The inherited checkpoint q.
    finalized_height: u64,
    /// The hash at q.
    finalized_hash: B256,
    /// The first installed header: the header floor.
    first_header: u64,
    /// The last installed header, s.
    last_header: u64,
}

/// Accept the EL receipt only if it names exactly the authenticated state, q and header range.
fn check_el(stdout: &[u8], expected: &ElIdentity) -> R<()> {
    let receipt: ElIdentity = serde_json::from_slice(stdout)
        .map_err(|_| unavailable("invalid etna-el-import receipt"))?;
    if receipt != *expected {
        return Err(unavailable(format!(
            "etna-el-import installed {receipt:?}, not the authenticated checkpoint {expected:?}"
        )));
    }
    Ok(())
}

/// Original EL identity derived from the operator-selected runtime chainspec, never a package.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ChainIdentity {
    /// Runtime chain identifier opened by the pinned helper.
    chain_id: u64,
    /// Original EL block-zero hash, distinct from the Inbox's Etna start hash.
    genesis_hash: B256,
}

/// Ask the pinned helper for the identity of the operator's original EL runtime configuration.
/// The subsequent install checks that same configuration against this independently selected
/// identity, preserving full receipt comparison when Etna's origin is above block zero.
async fn chain_identity(lock: &File, inputs: &Inputs, chain_id: u64) -> R<B256> {
    let mut command = helper_command(lock, &inputs.el_helper);
    command
        .arg("chain-identity")
        .arg("--chain")
        .arg(&inputs.el_chain)
        .arg("--chain-id")
        .arg(chain_id.to_string());
    let output = run(command, "etna-el-import chain-identity").await?;
    match output.status.code() {
        Some(0) => {}
        Some(1) => return Err(bad("etna-el-import rejected the runtime chain; see its stderr")),
        _ => return Err(unavailable("etna-el-import could not read the runtime chain identity")),
    }
    let identity: ChainIdentity = serde_json::from_slice(&output.stdout)
        .map_err(|_| unavailable("invalid etna-el-import chain identity"))?;
    if identity.chain_id != chain_id || identity.genesis_hash.is_zero() {
        return Err(unavailable("etna-el-import runtime chain identity differs"));
    }
    Ok(identity.genesis_hash)
}

/// Install the EL store once from the stopped `--el-source` into the absent `stage/ready/el`,
/// with every authenticated header from the header floor through s (DATA-5.4-4). Exit 1 rejects
/// the dataset or manifest as a candidate; any other failure is unavailable.
pub(super) async fn el_install(
    lock: &File,
    inputs: &Inputs,
    stage: &Path,
    manifest: &Manifest<'_>,
    params: &abci::ChainParams,
    v: &VerifiedImport,
) -> R<()> {
    let ready = stage.join("ready");
    let datadir = ready.join("el");
    // The helper creates the datadir itself; the stage keeps its parent.
    if !fs::metadata(&ready).map_err(io)?.is_dir() || exists(&datadir)? {
        return Err(unavailable("the EL install needs stage/ready and no stage/ready/el"));
    }
    let terminal = manifest.headers.last().ok_or_else(|| bad("missing terminal header"))?;
    let expected = ElIdentity {
        chain_id: params.l2_chain_id,
        genesis_hash: chain_identity(lock, inputs, params.l2_chain_id).await?,
        height: v.landing().height,
        block_hash: v.landing().el_hash,
        state_root: terminal.state_root,
        finalized_height: manifest.finalized_height,
        finalized_hash: manifest.finalized_hash,
        first_header: manifest.headers.first().ok_or_else(|| bad("missing first header"))?.number,
        last_header: v.landing().height,
    };
    let path = stage.join("headers.jsonl");
    manifest.write(&path)?;
    let mut command = helper_command(lock, &inputs.el_helper);
    command
        .arg("install")
        .arg("--source")
        .arg(&inputs.el_source)
        .arg("--datadir")
        .arg(&datadir)
        .arg("--scratch-parent")
        .arg(stage.join("scratch"))
        .arg("--chain")
        .arg(&inputs.el_chain)
        .arg("--manifest")
        .arg(&path)
        .arg("--chain-id")
        .arg(params.l2_chain_id.to_string())
        .arg("--trusted-el-hash")
        .arg(v.landing().el_hash.to_string())
        .arg("--trusted-state-root")
        .arg(terminal.state_root.to_string())
        .arg("--trusted-genesis-hash")
        .arg(expected.genesis_hash.to_string());
    let output = run(command, "etna-el-import").await?;
    match output.status.code() {
        Some(0) => check_el(&output.stdout, &expected),
        Some(1) => Err(bad("etna-el-import rejected the EL dataset or manifest; see its stderr")),
        _ => Err(unavailable(format!(
            "etna-el-import install failed ({}); see its stderr",
            output.status
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn comet() -> (CometReport, Value) {
        let report = CometReport {
            first_height: 3,
            last_height: 6,
            block_id: BlockId {
                hash: B256::repeat_byte(1),
                parts: Parts { total: 2, hash: B256::repeat_byte(2) },
            },
        };
        let receipt = json!({"first_height":3,"last_height":6,"block_id":{"hash":B256::repeat_byte(1),"parts":{"total":2,"hash":B256::repeat_byte(2)}}});
        (report, receipt)
    }

    /// DATA-5.4-4: the stock install gets the AppHash it is given as `--app-hash`.
    /// `comet_install` gives it only [`VerifiedImport::app_hash`], whose value
    /// `import_post_s_app_hash_is_app_hash` pins to header(s + 1)'s app_hash. ENC-A-29b.g: ELHash
    /// `0x11…11` and valStateHash `0x368f…a81b` give `0x381c…b451`.
    #[test]
    fn comet_install_passes_the_app_hash() {
        let el_hash = B256::repeat_byte(0x11);
        let app_hash = abci::valstate::app_hash(
            el_hash,
            alloy_primitives::b256!(
                "368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b"
            ),
        );
        let args = comet_install_args(Path::new("/c/home"), Path::new("/c/stock"), app_hash);
        assert_eq!(
            args,
            [
                "install",
                "--home",
                "/c/home",
                "--stock-dir",
                "/c/stock",
                "--app-hash",
                "0x381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451",
            ]
        );
        assert!(!args.contains(&el_hash.to_string().into()));
    }

    /// The stock receipt must name the authenticated window and the own-L1 landed Comet hash.
    #[test]
    fn comet_receipt_must_name_the_authenticated_window() {
        let (expected, receipt) = comet();
        let landed = B256::repeat_byte(1);
        check_comet(&serde_json::to_vec(&receipt).unwrap(), &expected, landed).unwrap();
        // Go's encoder ends the line with a newline.
        check_comet(format!("{receipt}\n").as_bytes(), &expected, landed).unwrap();
        for (pointer, value) in [
            ("/first_height", json!(2)),
            ("/last_height", json!(7)),
            ("/block_id/hash", json!(B256::repeat_byte(9))),
            ("/block_id/parts/total", json!(1)),
            ("/block_id/parts/hash", json!(B256::repeat_byte(9))),
        ] {
            let mut changed = receipt.clone();
            *changed.pointer_mut(pointer).unwrap() = value;
            assert!(
                matches!(
                    check_comet(&serde_json::to_vec(&changed).unwrap(), &expected, landed),
                    Err(ImportError::Unavailable(_))
                ),
                "{pointer}"
            );
        }
        let mut extra = receipt.clone();
        extra["installed"] = json!(true);
        for bytes in [serde_json::to_vec(&extra).unwrap(), b"".to_vec()] {
            assert!(matches!(
                check_comet(&bytes, &expected, landed),
                Err(ImportError::Unavailable(_))
            ));
        }
        assert!(matches!(
            check_comet(&serde_json::to_vec(&receipt).unwrap(), &expected, B256::repeat_byte(3)),
            Err(ImportError::Unavailable(_))
        ));
    }

    /// Every identity field of the EL receipt is compared; informational fields are not.
    #[test]
    fn el_receipt_must_name_the_authenticated_state_and_header_range() {
        let expected = ElIdentity {
            chain_id: 167001,
            genesis_hash: B256::repeat_byte(1),
            height: 900,
            block_hash: B256::repeat_byte(2),
            state_root: B256::repeat_byte(3),
            finalized_height: 606,
            finalized_hash: B256::repeat_byte(4),
            first_header: 600,
            last_header: 900,
        };
        let receipt = json!({
            "schema": 1, "helper_version": "0.1.0", "alethia_revision": "a", "reth_revision": "r",
            "chain_id": 167001, "genesis_hash": B256::repeat_byte(1), "height": 900,
            "block_hash": B256::repeat_byte(2), "state_root": B256::repeat_byte(3),
            "finalized_height": 606, "finalized_hash": B256::repeat_byte(4), "first_header": 600,
            "last_header": 900, "header_count": 301,
            "state": {"accounts": 1, "storage_slots": 0, "bytecodes": 0, "storage_v2": true}
        });
        check_el(&serde_json::to_vec(&receipt).unwrap(), &expected).unwrap();
        for (key, value) in [
            ("chain_id", json!(1)),
            ("genesis_hash", json!(B256::repeat_byte(9))),
            ("height", json!(899)),
            ("block_hash", json!(B256::repeat_byte(9))),
            ("state_root", json!(B256::repeat_byte(9))),
            ("finalized_height", json!(600)),
            ("finalized_hash", json!(B256::repeat_byte(9))),
            ("first_header", json!(601)),
            ("last_header", json!(899)),
        ] {
            let mut changed = receipt.clone();
            changed[key] = value;
            assert!(
                matches!(
                    check_el(&serde_json::to_vec(&changed).unwrap(), &expected),
                    Err(ImportError::Unavailable(_))
                ),
                "{key}"
            );
            changed.as_object_mut().unwrap().remove(key);
            assert!(check_el(&serde_json::to_vec(&changed).unwrap(), &expected).is_err(), "{key}");
        }
    }
}
