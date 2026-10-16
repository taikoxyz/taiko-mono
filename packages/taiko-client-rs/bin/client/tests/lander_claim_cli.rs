//! Offline acceptance checks for the real independent claim command.
use std::process::Command;

const CLIENT: &str = env!("CARGO_BIN_EXE_taiko-client");

#[test]
fn claim_command_exposes_required_inputs_without_recipient_redirect() {
    let output = Command::new(CLIENT).args(["lander-claim", "--help"]).output().unwrap();
    assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    let help = String::from_utf8_lossy(&output.stdout);
    for flag in ["--l1.http", "--l2.http", "--landing-tx", "--batch-id", "--key-file", "--data-dir"]
    {
        assert!(help.contains(flag), "missing {flag}");
    }
    assert!(!help.contains("--recipient"));
}

#[test]
fn claim_requires_all_inputs() {
    let output = Command::new(CLIENT).arg("lander-claim").output().unwrap();
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stderr).contains("--landing-tx"));
}

use lander as claim_library;
#[allow(dead_code)]
#[path = "../../../crates/lander/tests/support/claim_rpc.rs"]
mod fixture;
use fixture::{Fault, Fixture};
use std::{
    path::Path,
    sync::{Arc, atomic::Ordering},
    time::Duration,
};

fn command(l1: &url::Url, l2: &url::Url, key: &Path, directory: &Path) -> tokio::process::Command {
    let id = fixture::identity();
    let mut cmd = tokio::process::Command::new(CLIENT);
    cmd.arg("lander-claim")
        .args(["--l1.http", l1.as_str(), "--l2.http", l2.as_str()])
        .arg("--landing-tx")
        .arg(id.landing_tx.to_string())
        .arg("--batch-id")
        .arg(id.batch_id.to_string())
        .arg("--key-file")
        .arg(key)
        .arg("--data-dir")
        .arg(directory)
        .args(["--rpc.timeout", "3"]);
    cmd
}
fn key(dir: &Path) -> std::path::PathBuf {
    let key = dir.join("payer.key");
    std::fs::write(&key, "0000000000000000000000000000000000000000000000000000000000000001")
        .unwrap();
    key
}

#[tokio::test]
async fn actual_cli_third_party_payer_claims_and_retains_signed_bytes_until_finality() {
    let fixture = Arc::new(Fixture::new(Fault::None, false));
    let l1 = fixture::server(fixture.clone(), true).await;
    let l2 = fixture::server(fixture.clone(), false).await;
    let dir = tempfile::tempdir().unwrap();
    let key = key(dir.path());
    let journal = dir.path().join("claim");
    *fixture.claim_directory.lock().unwrap() = Some(journal.clone());
    let output = tokio::time::timeout(
        Duration::from_secs(15),
        command(&l1.url, &l2.url, &key, &journal).output(),
    )
    .await
    .unwrap()
    .unwrap();
    assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    assert!(String::from_utf8_lossy(&output.stdout).contains("provisionally"));
    let state: serde_json::Value =
        serde_json::from_slice(&std::fs::read(journal.join("claim-state.json")).unwrap()).unwrap();
    assert_eq!(state["job"]["state"], "Included");
    assert!(!state["job"]["transaction"]["bytes"].as_str().unwrap().is_empty());
    let payer: alloy_primitives::Address =
        serde_json::from_value(state["identity"]["payer"].clone()).unwrap();
    assert_ne!(payer, fixture::receipt().l2RewardRecipient);
    use alloy::sol_types::SolCall;
    use alloy_consensus::Transaction;
    use alloy_eips::eip2718::Decodable2718;
    let raw = fixture.sends.lock().unwrap()[0].clone();
    let envelope = alloy_consensus::TxEnvelope::decode_2718(&mut raw.as_ref()).unwrap();
    let call = lander::claim::Vault::claimCall::abi_decode(envelope.input()).unwrap();
    assert_eq!(call._receipt.l2RewardRecipient, fixture::receipt().l2RewardRecipient);
    assert_eq!(call._receipt.baseFeeAmount, alloy_primitives::U256::from(11));
}

#[tokio::test]
async fn actual_cli_unknown_send_restart_rebroadcasts_same_bytes_before_any_new_proof() {
    let fixture = Arc::new(Fixture::new(Fault::None, false));
    fixture.fail_next_send.store(true, Ordering::SeqCst);
    let l1 = fixture::server(fixture.clone(), true).await;
    let l2 = fixture::server(fixture.clone(), false).await;
    let dir = tempfile::tempdir().unwrap();
    let key = key(dir.path());
    let journal = dir.path().join("claim");
    *fixture.claim_directory.lock().unwrap() = Some(journal.clone());
    let first = command(&l1.url, &l2.url, &key, &journal).output().await.unwrap();
    assert!(!first.status.success());
    let state: serde_json::Value =
        serde_json::from_slice(&std::fs::read(journal.join("claim-state.json")).unwrap()).unwrap();
    assert_eq!(state["job"]["state"], "Pending");
    let proof_reads =
        fixture.requests.lock().unwrap().iter().filter(|r| r["method"] == "eth_getProof").count();
    let second = tokio::time::timeout(
        Duration::from_secs(15),
        command(&l1.url, &l2.url, &key, &journal).output(),
    )
    .await
    .unwrap()
    .unwrap();
    assert!(second.status.success(), "{}", String::from_utf8_lossy(&second.stderr));
    let sends = fixture.sends.lock().unwrap();
    assert_eq!(sends.len(), 2);
    assert_eq!(sends[0], sends[1]);
    // Exactly one new proof is the finalized checkpoint; entitlement preparation must not repeat.
    assert_eq!(
        fixture.requests.lock().unwrap().iter().filter(|r| r["method"] == "eth_getProof").count(),
        proof_reads + 1
    );
}

#[tokio::test]
async fn actual_cli_invalid_chain_zero_inbox_and_rpc_errors_do_not_leak_credentials() {
    for fault in [Fault::WrongChain, Fault::ZeroInbox, Fault::RpcLeak] {
        let fixture = Arc::new(Fixture::new(fault, false));
        let l1 = fixture::server(fixture.clone(), true).await;
        let l2 = fixture::server(fixture.clone(), false).await;
        let dir = tempfile::tempdir().unwrap();
        let key = key(dir.path());
        let journal = dir.path().join("claim");
        let output = command(&l1.url, &l2.url, &key, &journal).output().await.unwrap();
        assert!(!output.status.success());
        let diagnostic = format!(
            "{}{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
        assert!(!diagnostic.contains("secret-"), "{diagnostic}");
        assert!(!journal.exists());
    }
}

#[test]
fn actual_cli_rejects_each_missing_flag_malformed_batch_and_zero_hash_before_key_access() {
    let hash = format!("0x{}", "11".repeat(32));
    let args = vec![
        "lander-claim",
        "--l1.http",
        "http://127.0.0.1:1",
        "--l2.http",
        "http://127.0.0.1:2",
        "--landing-tx",
        &hash,
        "--batch-id",
        &hash,
        "--key-file",
        "/does-not-exist",
        "--data-dir",
        "/does-not-exist",
    ];
    for flag in ["--l1.http", "--l2.http", "--landing-tx", "--batch-id", "--key-file", "--data-dir"]
    {
        let mut a = args.clone();
        let i = a.iter().position(|v| *v == flag).unwrap();
        a.drain(i..i + 2);
        let output = Command::new(CLIENT).args(a).output().unwrap();
        assert!(!output.status.success());
        assert!(String::from_utf8_lossy(&output.stderr).contains(flag));
    }
    let zero = format!("0x{}", "00".repeat(32));
    for bad in ["not-a-hash", zero.as_str()] {
        let mut a = args.clone();
        let i = a.iter().position(|v| *v == "--batch-id").unwrap();
        a[i + 1] = bad;
        let output = Command::new(CLIENT).args(a).output().unwrap();
        assert!(!output.status.success());
        assert!(!String::from_utf8_lossy(&output.stderr).contains("cannot read"));
    }
}
