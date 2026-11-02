//! Actual foreground controller and Python supervisor, with controlled private app/signer peers.
use super::*;
use std::os::unix::fs::PermissionsExt;

const APP: &str = r#"import json,os,socket,sys
from pathlib import Path
root=Path(sys.argv[1]); app=Path(sys.argv[sys.argv.index('--data-dir')+1])
base=json.loads((root/'snapshot.json').read_text()); counter=0
listener=socket.socket(socket.AF_UNIX);listener.bind(str(app/'checkpoint-trust.sock'));os.chmod(app/'checkpoint-trust.sock',0o600);listener.listen()
while True:
 peer,_=listener.accept()
 with peer:
  request=json.loads(peer.makefile('rb').readline())
  with (root/'operations').open('a') as out:out.write(request['op']+'\n')
  if request['op']=='begin_session':counter+=1
  mode=json.loads((root/'mode.json').read_text()); ready=mode['ready_session']==counter
  response=dict(base,session_id='boot:'+str(counter),phase='ready' if ready else 'acquiring',trust_ready=ready,syncing=not ready)
  if not ready:response['trusted_consensus_head']=None
  peer.sendall((json.dumps(response)+'\n').encode())
"#;
const SIGNER: &str = r#"import json,os,socket,sys,time
from pathlib import Path
root=Path(sys.argv[1]);control=sys.argv[sys.argv.index('--trust-socket')+1];events=Path(sys.argv[sys.argv.index('--denial-file')+1])
while True:
 try:
  peer=socket.socket(socket.AF_UNIX);peer.connect(control);break
 except OSError:peer.close();time.sleep(.01)
with peer:
 peer.sendall(b'{"schema_version":2,"op":"begin_session"}\n');snapshot=json.loads(peer.makefile('rb').readline())
session=snapshot['session_id'];sequence=1 if session=='boot:1' else 0
pending=events.with_suffix('.pending');pending.write_text(json.dumps(dict(sequence=sequence,session_id=session)));pending.chmod(0o600);os.replace(pending,events)
with (root/'signer-starts').open('a') as out:out.write(session+'\n')
while True:time.sleep(.01)
"#;

fn atomic_json(path: &Path, value: &serde_json::Value) {
    let pending = path.with_extension("pending");
    std::fs::write(&pending, serde_json::to_vec(value).unwrap()).unwrap();
    std::fs::set_permissions(&pending, std::fs::Permissions::from_mode(0o600)).unwrap();
    std::fs::rename(pending, path).unwrap();
}
async fn eventually(mut condition: impl FnMut() -> bool) {
    tokio::time::timeout(std::time::Duration::from_secs(10), async {
        while !condition() {
            tokio::time::sleep(std::time::Duration::from_millis(20)).await;
        }
    })
    .await
    .unwrap();
}

#[tokio::test]
async fn recovery_controller_owned_supervisor_recovers_initial_and_later_refusal() {
    let dir = tempfile::tempdir_in("/private/tmp").unwrap();
    let base = dir.path();
    let source = Source {
        fixture: serde_json::from_str(include_str!("testdata/session.json")).unwrap(),
        finalized: Mutex::new(VecDeque::new()),
    };
    let mut profile = native_profile(base, &source);
    profile.app.argv = vec!["-c".into(), APP.into(), base.display().to_string()];
    profile.role = NodeRole::Validator;
    let signer = SignerProfile {
        key: base.join("key.json"),
        state: base.join("hrs.json"),
        authority: base.join("authority"),
        executable: Executable {
            program: "/usr/bin/python3".into(),
            argv: vec!["-c".into(), SIGNER.into(), base.display().to_string()],
            env: BTreeMap::new(),
        },
        supervisor: Executable {
            program: "/usr/bin/python3".into(),
            argv: vec![
                Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../../script/etna_validator.py")
                    .canonicalize()
                    .unwrap()
                    .display()
                    .to_string(),
            ],
            env: BTreeMap::new(),
        },
    };
    std::fs::write(&signer.key, b"registered-key-never-copied").unwrap();
    std::fs::write(&signer.state, b"original HRS unchanged").unwrap();
    std::fs::create_dir(&signer.authority).unwrap();
    let recovered = signer.authority.join("generation-one.json");
    std::fs::write(&recovered, b"generation-one HRS unchanged").unwrap();
    let python = std::process::Command::new("python3")
        .args(["-c", "import sys,tomllib;print(sys.executable)"])
        .output()
        .unwrap();
    assert!(python.status.success(), "Python 3.11+ required for actual supervisor");
    let mut signer = signer;
    signer.supervisor.program = String::from_utf8(python.stdout).unwrap().trim().into();
    profile.signer = Some(signer.clone());
    std::fs::write(profile.comet_home.join("config/config.toml"),format!("proxy_app='tcp://127.0.0.1:26658'\npriv_validator_laddr='unix://{}'\n[p2p]\npersistent_peers=''\n",base.join("old-signer.sock").display())).unwrap();
    let root = base.join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let o = &plan.origin;
    let chain = abci::rules::chain_id_for(&plan.deployment.params().unwrap(), 1).unwrap();
    let landing = crate::recovery::activate::finalized_landing(&source, &plan).await.unwrap();
    let snapshot = serde_json::json!({"schema_version":2,"session_id":"boot:0","chain_id":chain,"generation":1,"recovery_origin":{"generation":1,"height":o.height,"l1_number":o.l1_number,"l1_hash":plan.validate().unwrap().recovery_header.hash(),"l1_timestamp":o.l1_timestamp,"el_hash":o.el_hash,"comet_hash":o.comet_hash,"forced_cursor":o.forced_cursor,"committee_hash":o.committee.record.set_root},"trust_ready":false,"syncing":true,"phase":"acquiring","target":landing.target,"committed_head":{"height":o.height,"hash":o.el_hash},"trusted_consensus_head":{"height":o.height,"hash":o.el_hash},"reason":null});
    atomic_json(&base.join("snapshot.json"), &snapshot);
    atomic_json(&base.join("mode.json"), &serde_json::json!({"ready_session":0}));
    let engine = ProbeEngine {
        reader: ReadEngine::new(&source),
        built_on: Mutex::new(vec![]),
        malformed: false,
    };
    let original_hrs = std::fs::read(&signer.state).unwrap();
    let recovered_hrs = std::fs::read(&recovered).unwrap();
    let observed = |session: &str, trusted: bool| {
        store.load_journal(plan.id()).unwrap().is_some_and(|j| {
            j.progress.is_some_and(|p| p.session_id == session && p.trusted == trusted)
        })
    };
    let drive = async {
        eventually(|| observed("boot:1", false)).await;
        atomic_json(&base.join("mode.json"), &serde_json::json!({"ready_session":1}));
        eventually(|| observed("boot:2", false)).await;
        assert_eq!(std::fs::read(&signer.state).unwrap(), original_hrs);
        atomic_json(&base.join("mode.json"), &serde_json::json!({"ready_session":2}));
        eventually(|| observed("boot:2", true)).await;
        atomic_json(&base.join("mode.json"), &serde_json::json!({"ready_session":0}));
        atomic_json(
            &store.plan_dir(plan.id()).join("app/signer-denial.json"),
            &serde_json::json!({"sequence":1,"session_id":"boot:2"}),
        );
        eventually(|| observed("boot:2", false)).await;
        atomic_json(&base.join("mode.json"), &serde_json::json!({"ready_session":2}));
        eventually(|| observed("boot:3", false)).await;
        assert!(!store.load_journal(plan.id()).unwrap().unwrap().progress.unwrap().trusted);
        atomic_json(&base.join("mode.json"), &serde_json::json!({"ready_session":3}));
        eventually(|| observed("boot:3", true)).await;
        eventually(|| {
            std::fs::read_to_string(base.join("children.log"))
                .unwrap_or_default()
                .matches("comet:start")
                .count() ==
                3
        })
        .await;
    };
    crate::recovery::activate::activate_with(profile, root, plan.id(), &source, &engine, drive)
        .await
        .unwrap();
    assert_eq!(
        std::fs::read_to_string(base.join("signer-starts")).unwrap().lines().collect::<Vec<_>>(),
        ["boot:1", "boot:2", "boot:3"]
    );
    assert_eq!(
        std::fs::read_to_string(base.join("operations"))
            .unwrap()
            .lines()
            .filter(|op| *op == "begin_session")
            .count(),
        3,
        "only the three owned signer incarnations may BeginSession"
    );
    assert_eq!(std::fs::read(&signer.state).unwrap(), original_hrs);
    assert_eq!(std::fs::read(&recovered).unwrap(), recovered_hrs);
    assert_eq!(std::fs::read(&signer.key).unwrap(), b"registered-key-never-copied");
}
