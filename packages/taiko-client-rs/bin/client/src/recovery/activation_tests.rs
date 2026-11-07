use super::*;
use crate::recovery::activate::probe_recovery_state;
use abci::types::{AnchorState, ParentInfo};

struct ProbeEngine {
    reader: ReadEngine,
    built_on: Mutex<Vec<B256>>,
    malformed: bool,
}
#[async_trait::async_trait]
impl Engine for ProbeEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        Ok(())
    }
    async fn pool_transactions(&self, _: PoolSelection) -> Result<Vec<TxEnvelope>, EngineError> {
        panic!("probe must not select mempool")
    }
    async fn build_block(
        &self,
        parent: B256,
        attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        self.built_on.lock().unwrap().push(parent);
        assert_eq!(attrs.block_metadata.tx_list, Some(Bytes::from_static(&[0xc0])));
        let header = Header {
            number: 7,
            parent_hash: if self.malformed { B256::ZERO } else { parent },
            timestamp: attrs.payload_attributes.timestamp,
            beneficiary: attrs.block_metadata.beneficiary,
            extra_data: attrs.block_metadata.extra_data,
            parent_beacon_block_root: attrs.payload_attributes.parent_beacon_block_root,
            gas_limit: attrs.block_metadata.gas_limit,
            base_fee_per_gas: Some(attrs.base_fee_per_gas.to()),
            mix_hash: attrs.block_metadata.mix_hash,
            withdrawals_root: Some(alloy_consensus::constants::EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            requests_hash: Some(alloy_eips::eip7685::EMPTY_REQUESTS_HASH),
            ..Header::default()
        };
        Ok(ExecutionBlock { header, transactions: vec![] })
    }
    async fn new_payload(&self, _: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        panic!("probe must never import candidate")
    }
    async fn forkchoice(&self, _: B256, _: B256, _: B256) -> Result<PayloadVerdict, EngineError> {
        panic!("probe must never promote candidate")
    }
    async fn header_by_number(&self, n: u64) -> Result<Option<Header>, EngineError> {
        self.reader.header_by_number(n).await
    }
    async fn finalized_header(&self) -> Result<Option<Header>, EngineError> {
        self.reader.finalized_header().await
    }
    async fn historical_state_available(&self, h: B256) -> Result<bool, EngineError> {
        self.reader.historical_state_available(h).await
    }
}
async fn probe_context(
    source: &Source,
) -> (abci::recovery::RecoveryOrigin, ParentInfo, AnchorState) {
    let witness = source.witness();
    let origin =
        verify_recovery_witness(&witness, &source.fixture.params.params().unwrap()).unwrap();
    let h = &witness.el_header;
    let parent = ParentInfo {
        number: h.number,
        hash: h.hash_slow(),
        timestamp: h.timestamp,
        gas_limit: h.gas_limit,
        gas_used: h.gas_used,
        base_fee: h.base_fee_per_gas.unwrap(),
        difficulty: h.difficulty,
        grandparent_timestamp: witness.parent_headers[0].timestamp,
    };
    let anchor = abci::l1::verify_anchor_witness(
        &abci::envelope::AnchorWitness {
            l1_header: witness.recovery_header,
            inbox: source
                .account_witness(
                    source.fixture.params.inbox,
                    &abci::l1::layout::inbox::anchor_slots(),
                    origin.l1_number,
                )
                .await
                .unwrap(),
        },
        source.fixture.params.inbox,
    )
    .unwrap();
    (origin, parent, anchor)
}
#[tokio::test]
async fn recovery_el_origin_ready_does_not_require_head_rewind() {
    let source = Source::new();
    let (origin, parent, anchor) = probe_context(&source).await;
    let mut reader = ReadEngine::new(&source);
    let old_canonical_head = 18;
    reader.headers.push(Header { number: old_canonical_head, ..Header::default() });
    let engine = ProbeEngine { reader, built_on: Mutex::new(vec![]), malformed: false };
    probe_recovery_state(
        &engine,
        &source.fixture.params.params().unwrap(),
        &origin,
        &parent,
        &anchor,
    )
    .await
    .unwrap();
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let p = configured_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan = prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let mut journal = ActivationJournal::prepared(plan.id());
    journal.phase = ActivationPhase::ElOriginReady;
    store.save_journal(&journal).unwrap();
    assert_eq!(journal.phase, ActivationPhase::ElOriginReady);
    assert_ne!(status(&store, plan.id()).unwrap().phase, ActivationPhase::Settled);
    assert!(old_canonical_head > 6);
    assert_eq!(*engine.built_on.lock().unwrap(), vec![origin.el_hash]);
    assert_eq!(
        engine.header_by_number(old_canonical_head).await.unwrap().unwrap().number,
        old_canonical_head
    );
}
#[tokio::test]
async fn recovery_probe_rejects_pruned_state_and_contradictory_candidate() {
    let source = Source::new();
    let (origin, parent, anchor) = probe_context(&source).await;
    let mut engine = ProbeEngine {
        reader: ReadEngine::new(&source),
        built_on: Mutex::new(vec![]),
        malformed: false,
    };
    engine.reader.available = false;
    assert!(
        probe_recovery_state(
            &engine,
            &source.fixture.params.params().unwrap(),
            &origin,
            &parent,
            &anchor
        )
        .await
        .is_err()
    );
    assert!(engine.built_on.lock().unwrap().is_empty());
    engine.reader.available = true;
    engine.malformed = true;
    assert!(matches!(
        probe_recovery_state(
            &engine,
            &source.fixture.params.params().unwrap(),
            &origin,
            &parent,
            &anchor
        )
        .await,
        Err(RecoveryCommandError::Invalid)
    ));
}

#[tokio::test]
async fn recovery_activation_descriptor_is_atomic_bound_and_repeatable() {
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    install_transport_key(&p);
    let root = dir.path().join("recovery");
    let prepared =
        prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let descriptor = installed_descriptor(&store, &prepared, &p);
    assert_eq!(store.load_active().unwrap(), None);
    store.publish_active(&descriptor, None).unwrap();
    assert_eq!(store.load_active().unwrap(), Some(descriptor.clone()));
    store.publish_active(&descriptor, Some(&descriptor)).unwrap();
    let mut foreign = descriptor.clone();
    foreign.generation += 1;
    assert!(store.publish_active(&foreign, Some(&descriptor)).is_err());
    assert_eq!(store.load_active().unwrap(), Some(descriptor));
}

#[tokio::test]
async fn recovery_activation_each_durable_phase_roundtrips_without_live_authority() {
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let root = dir.path().join("recovery");
    let plan = prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    for phase in [
        ActivationPhase::Prepared,
        ActivationPhase::Stopping,
        ActivationPhase::Isolated,
        ActivationPhase::ElOriginReady,
        ActivationPhase::Installed,
        ActivationPhase::Running,
        ActivationPhase::Trusted,
        ActivationPhase::Settled,
    ] {
        let mut journal = ActivationJournal::prepared(plan.id());
        journal.phase = phase;
        store.save_journal(&journal).unwrap();
        assert_eq!(store.load_journal(plan.id()).unwrap().unwrap(), journal);
        let report = status(&store, plan.id()).unwrap();
        assert_eq!(report.phase, phase);
        assert!(matches!(report.component_state, ComponentObservation::NotObserved));
        assert!(!report.live_trust);
    }
}

#[tokio::test]
async fn recovery_activation_publication_faults_leave_whole_selector_and_retry() {
    for failed_boundary in ["bundle-synced", "selector-synced", "selector-renamed", "root-synced"] {
        let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
        let source = Source::new();
        let p = configured_profile(dir.path(), &source);
        install_transport_key(&p);
        let root = dir.path().join("recovery");
        let plan =
            prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
        let store = RecoveryStore::new(&root);
        let descriptor = installed_descriptor(&store, &plan, &p);
        assert!(
            store
                .publish_active_steps(&descriptor, None, |boundary| {
                    if boundary == failed_boundary {
                        Err(RecoveryCommandError::Io("injected fault"))
                    } else {
                        Ok(())
                    }
                })
                .is_err()
        );
        if let Some(active) = store.load_active().unwrap() {
            assert_eq!(active, descriptor);
        }
        store.publish_active(&descriptor, None).unwrap();
        assert_eq!(store.load_active().unwrap(), Some(descriptor));
    }
}

#[tokio::test]
async fn recovery_activation_trust_requires_exact_private_session_and_settlement() {
    use crate::recovery::{activate::FinalizedLanding, status::record_observation};
    use abci::app::trust::{
        BlockRef, CheckpointTarget, RecoveryTrustOrigin, TrustPhase, TrustSnapshot,
    };
    let source = Source::new();
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let plan = plan(&profile(dir.path()), &source).await;
    let o = &plan.origin;
    let target = CheckpointTarget {
        l1_number: 110,
        l1_hash: B256::repeat_byte(1),
        height: o.height,
        hash: o.el_hash,
        comet_hash: o.comet_hash,
        val_state_hash: o.val_state_hash,
        generation: o.generation,
        inbox: plan.deployment.inbox,
    };
    let origin = RecoveryTrustOrigin {
        generation: o.generation,
        height: o.height,
        l1_number: o.l1_number,
        l1_hash: source.witness().recovery_header.hash(),
        l1_timestamp: o.l1_timestamp,
        el_hash: o.el_hash,
        comet_hash: o.comet_hash,
        forced_cursor: o.forced_cursor,
        committee_hash: o.committee.record.set_root,
    };
    let head = BlockRef { height: o.height, hash: o.el_hash };
    let mut snapshot = TrustSnapshot {
        schema_version: 1,
        session_id: "opaque:1".into(),
        chain_id: Some(
            abci::rules::chain_id_for(&plan.deployment.params().unwrap(), o.generation).unwrap(),
        ),
        generation: Some(o.generation),
        recovery_origin: Some(origin),
        trust_ready: true,
        syncing: false,
        phase: TrustPhase::Ready,
        target: Some(target.clone()),
        committed_head: Some(head.clone()),
        trusted_consensus_head: Some(head),
        reason: None,
    };
    let mut landing = FinalizedLanding { target, landing_generation: 0 };
    let mut journal = ActivationJournal::prepared(plan.id());
    record_observation(&plan, &mut journal, &snapshot, "opaque:1", &landing).unwrap();
    assert_eq!(journal.phase, ActivationPhase::Trusted);
    assert_eq!(journal.progress.as_ref().unwrap().committed_height, None);
    assert!(record_observation(&plan, &mut journal, &snapshot, "stale:1", &landing).is_err());
    snapshot.committed_head = Some(BlockRef { height: 12, hash: B256::repeat_byte(12) });
    snapshot.trusted_consensus_head = snapshot.committed_head.clone();
    record_observation(&plan, &mut journal, &snapshot, "opaque:1", &landing).unwrap();
    assert_eq!(journal.phase, ActivationPhase::Trusted, "local commit is not settlement");
    landing.target.height = 12;
    landing.target.hash = B256::repeat_byte(12);
    landing.landing_generation = 1;
    snapshot.target = Some(landing.target.clone());
    record_observation(&plan, &mut journal, &snapshot, "opaque:1", &landing).unwrap();
    assert_eq!(journal.phase, ActivationPhase::Settled);
    snapshot.trust_ready = false;
    snapshot.syncing = true;
    snapshot.phase = TrustPhase::CatchingUp;
    snapshot.trusted_consensus_head = None;
    record_observation(&plan, &mut journal, &snapshot, "opaque:1", &landing).unwrap();
    assert_eq!(
        journal.phase,
        ActivationPhase::Running,
        "settled observations cannot keep stale trust live"
    );
}

#[tokio::test]
async fn recovery_activation_rechecks_generation_before_and_after_locks() {
    for initial_reads in [0, 1] {
        let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
        let source = Source::new();
        let p = configured_profile(dir.path(), &source);
        let root = dir.path().join("recovery");
        let plan =
            prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
        source
            .finalized
            .lock()
            .unwrap()
            .extend(std::iter::repeat_n(110, initial_reads).chain([130]));
        assert!(matches!(
            crate::recovery::activate::isolate(&p, &root, &plan, &source).await,
            Err(RecoveryCommandError::Superseded { requested: 1, current: 2 })
        ));
        assert!(!root.join("active.json").exists());
    }
}
#[tokio::test]
async fn recovery_activation_same_generation_target_advances_without_changing_genesis() {
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let root = dir.path().join("recovery");
    let plan = prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    source.finalized.lock().unwrap().extend([110, 120]);
    let mut runtime = crate::recovery::activate::isolate(&p, &root, &plan, &source).await.unwrap();
    assert_eq!(RecoveryStore::new(&root).load_plan(plan.id()).unwrap().genesis, plan.genesis);
    runtime.stop().await.unwrap();
}

#[tokio::test]
async fn recovery_activation_landing_uses_own_finalized_proofs_and_landing_generation() {
    let source = Source {
        fixture: serde_json::from_str(include_str!("testdata/activation.json")).unwrap(),
        finalized: Mutex::new(VecDeque::new()),
    };
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let plan = plan(&profile(dir.path()), &source).await;
    let initial = crate::recovery::activate::finalized_landing(&source, &plan).await.unwrap();
    assert_eq!(initial.target.height, 12);
    assert_eq!(initial.landing_generation, 1);
    source.finalized.lock().unwrap().extend([120, 120]);
    let later = crate::recovery::activate::finalized_landing(&source, &plan).await.unwrap();
    assert_eq!(later.target.height, 18);
    assert_eq!(later.landing_generation, 1);
    source.finalized.lock().unwrap().push_back(130);
    assert!(matches!(
        crate::recovery::activate::finalized_landing(&source, &plan).await,
        Err(RecoveryCommandError::Superseded { requested: 1, current: 2 })
    ));
}

#[tokio::test]
async fn recovery_activation_installs_separate_bound_comet_home_with_private_p2p() {
    use crate::recovery::install;
    use std::os::unix::fs::{MetadataExt, PermissionsExt};
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = configured_profile(dir.path(), &source);
    let key = serde_json::to_vec(&test_harness::node_keys(1).remove(0).node_key_json()).unwrap();
    std::fs::write(profile.comet_home.join("config/node_key.json"), &key).unwrap();
    std::fs::set_permissions(
        profile.comet_home.join("config/node_key.json"),
        std::fs::Permissions::from_mode(0o600),
    )
    .unwrap();
    let root = dir.path().join("recovery");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let installed = install::binding(&profile, plan.id()).unwrap();
    assert!(!installed.home.starts_with(&root));
    install::reserve(&installed).unwrap();
    install::install(&RecoveryStore::new(&root), &plan, &installed).unwrap();
    assert_eq!(std::fs::read(installed.home.join("config/node_key.json")).unwrap(), key);
    let metadata = std::fs::metadata(installed.home.join("config/node_key.json")).unwrap();
    assert_eq!(metadata.permissions().mode() & 0o777, 0o600);
    assert_eq!(metadata.uid(), installed.uid);
    assert!(!installed.home.join("config/priv_validator_key.json").exists());
    install::install(&RecoveryStore::new(&root), &plan, &installed).unwrap();
    std::fs::write(installed.home.join("config/config.toml"), "foreign").unwrap();
    assert!(install::install(&RecoveryStore::new(&root), &plan, &installed).is_err());
}

fn install_transport_key(profile: &RecoveryProfile) {
    use std::os::unix::fs::PermissionsExt;
    let path = profile.comet_home.join("config/node_key.json");
    std::fs::write(
        &path,
        serde_json::to_vec(&test_harness::node_keys(1).remove(0).node_key_json()).unwrap(),
    )
    .unwrap();
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600)).unwrap();
}
fn installed_descriptor(
    store: &RecoveryStore,
    plan: &RecoveryPlan,
    p: &RecoveryProfile,
) -> ActiveDescriptor {
    let installed = crate::recovery::install::binding(p, plan.id()).unwrap();
    crate::recovery::install::reserve(&installed).unwrap();
    crate::recovery::install::install(store, plan, &installed).unwrap();
    ActiveDescriptor::for_plan(plan, installed)
}

#[tokio::test]
async fn recovery_activation_rejects_foreign_comet_identity_before_writers() {
    use crate::recovery::inspect::{Inspection, validate_stores};
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let p = configured_profile(dir.path(), &source);
    let root = dir.path().join("recovery");
    let plan = prepare::prepare(&p, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let mut report = Inspection {
        schema: 1,
        empty: false,
        chain_id: abci::rules::chain_id_for(&plan.deployment.params().unwrap(), 1).unwrap(),
        initial_height: 7,
        state_height: 0,
        state_app_hash: plan.origin.el_hash,
        state_comet_hash: B256::ZERO,
        blockstore_height: 0,
        validators_hash: abci::wire::validators_hash(&plan.origin.committee.members).unwrap(),
        next_validators_hash: abci::wire::validators_hash(&plan.origin.committee.members).unwrap(),
        blocks: vec![],
    };
    assert!(validate_stores(&RecoveryStore::new(&root), &plan, &report).unwrap().is_none());
    for change in 0..3 {
        let original = report.clone();
        match change {
            0 => report.chain_id = "foreign".into(),
            1 => report.initial_height = 1,
            _ => report.validators_hash = B256::ZERO,
        }
        assert!(validate_stores(&RecoveryStore::new(&root), &plan, &report).is_err());
        report = original;
    }
    assert!(!RecoveryStore::new(&root).plan_dir(plan.id()).join("app/abci-state.json").exists());
}

fn native_profile(dir: &Path, source: &Source) -> RecoveryProfile {
    let mut profile = configured_profile(dir, source);
    install_transport_key(&profile);
    let child = r#"import os,signal,sys,time
role=sys.argv[1]
log=sys.argv[2]
def record(value):
 with open(log,'a') as out: out.write(role+':'+value+'\n');out.flush();os.fsync(out.fileno())
def stop(*args):
 record('stop');sys.exit(0)
signal.signal(signal.SIGTERM,stop)
signal.signal(signal.SIGINT,stop)
record('start')
while True: time.sleep(.01)
"#;
    for (role, executable) in [("app", &mut profile.app), ("comet", &mut profile.comet)] {
        executable.program = "/usr/bin/python3".into();
        executable.argv = vec![
            "-c".into(),
            child.into(),
            role.into(),
            dir.join("children.log").display().to_string(),
        ];
    }
    let report = serde_json::json!({"schema":1,"empty":true,"chain_id":"","initial_height":0,"state_height":0,"state_app_hash":B256::ZERO,"state_comet_hash":B256::ZERO,"blockstore_height":0,"validators_hash":B256::ZERO,"next_validators_hash":B256::ZERO,"blocks":[]});
    std::fs::write(dir.join("inspection.json"), report.to_string()).unwrap();
    profile.inspector = Some(Executable {
        program: "/usr/bin/python3".into(),
        argv: vec![
            "-c".into(),
            "import sys;print(open(sys.argv[1]).read())".into(),
            dir.join("inspection.json").display().to_string(),
        ],
        env: BTreeMap::new(),
    });
    profile
}

#[tokio::test]
async fn recovery_activation_native_children_cancel_and_resume_retain_ordered_ownership() {
    use crate::recovery::activate::activate_with;
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = native_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let engine = ProbeEngine {
        reader: ReadEngine::new(&source),
        built_on: Mutex::new(vec![]),
        malformed: false,
    };
    for (attempt, phase) in [
        ActivationPhase::Prepared,
        ActivationPhase::Stopping,
        ActivationPhase::Isolated,
        ActivationPhase::ElOriginReady,
        ActivationPhase::Installed,
        ActivationPhase::Running,
        ActivationPhase::Trusted,
    ]
    .into_iter()
    .enumerate()
    {
        let mut journal = store
            .load_journal(plan.id())
            .unwrap()
            .unwrap_or_else(|| ActivationJournal::prepared(plan.id()));
        if phase == ActivationPhase::Trusted {
            initialized_state(&store, &plan, &source).await;
        }
        journal.phase = phase;
        store.save_journal(&journal).unwrap();
        let cancelled = async {
            tokio::time::timeout(std::time::Duration::from_secs(10), async {
                loop {
                    let log = std::fs::read_to_string(dir.path().join("children.log"))
                        .unwrap_or_default();
                    if log.matches("comet:start").count() > attempt &&
                        log.matches("app:start").count() > attempt
                    {
                        let observed = store.load_journal(plan.id()).unwrap().unwrap();
                        assert_eq!(observed.phase, ActivationPhase::Running);
                        assert!(abci::ownership::acquire_activation(&root, plan.id()).is_err());
                        break
                    }
                    tokio::time::sleep(std::time::Duration::from_millis(10)).await;
                }
            })
            .await
            .unwrap();
        };
        activate_with(profile.clone(), root.clone(), plan.id(), &source, &engine, cancelled)
            .await
            .unwrap();
        let log = std::fs::read_to_string(dir.path().join("children.log")).unwrap();
        assert!(log.rfind("comet:stop").unwrap() < log.rfind("app:stop").unwrap());
        let observed = store.load_journal(plan.id()).unwrap().unwrap();
        assert_eq!(observed.blocker, Some(ActivationBlocker::Stopped));
        assert_eq!(observed.components, ["app", "comet"]);
        assert!(abci::ownership::acquire_activation(&root, plan.id()).is_ok());
    }
    assert_eq!(*engine.built_on.lock().unwrap(), vec![plan.origin.el_hash; 7]);
}

#[tokio::test]
async fn recovery_activation_generic_latch_and_contradictory_phase_block_before_engine() {
    use crate::recovery::activate::activate_with;
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = native_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let engine = ProbeEngine {
        reader: ReadEngine::new(&source),
        built_on: Mutex::new(vec![]),
        malformed: false,
    };
    let store = RecoveryStore::new(&root);
    let mut journal = ActivationJournal::prepared(plan.id());
    journal.phase = ActivationPhase::Settled;
    store.save_journal(&journal).unwrap();
    assert!(matches!(
        activate_with(
            profile.clone(),
            root.clone(),
            plan.id(),
            &source,
            &engine,
            std::future::pending()
        )
        .await,
        Err(RecoveryCommandError::PlanMismatch)
    ));
    store.save_journal(&ActivationJournal::prepared(plan.id())).unwrap();
    std::fs::write(
        profile.app_data_dir.join("validator-supervisor.halted"),
        "superseded generation 0",
    )
    .unwrap();
    assert!(matches!(
        activate_with(
            profile.clone(),
            root.clone(),
            plan.id(),
            &source,
            &engine,
            std::future::pending()
        )
        .await,
        Err(RecoveryCommandError::Halted)
    ));
    assert!(engine.built_on.lock().unwrap().is_empty());
    assert!(!dir.path().join("children.log").exists());
}

async fn initialized_state(
    store: &RecoveryStore,
    plan: &RecoveryPlan,
    source: &Source,
) -> abci::store::AppState {
    let mut witness = plan.validate().unwrap();
    witness.finalized_header = witness.recovery_header.clone();
    witness.finalized_inbox = witness.recovery_inbox.clone();
    let (_, _, number) = abci::rules::decode_extra_data(&witness.el_header.extra_data).unwrap();
    let evidence = abci::AnchorWitness {
        l1_header: source.header(number).await.unwrap(),
        inbox: source
            .account_witness(
                plan.deployment.inbox,
                &abci::l1::layout::inbox::anchor_slots(),
                number,
            )
            .await
            .unwrap(),
    };
    let anchor = abci::l1::verify_anchor_witness(&evidence, plan.deployment.inbox).unwrap();
    let bootstrap = serde_json::json!({"version":1,"witness":Bytes::from(alloy_rlp::encode(&witness)),"anchor":Bytes::from(alloy_rlp::encode(&evidence))});
    std::fs::write(
        store.plan_dir(plan.id()).join("app/recovery-bootstrap.json"),
        serde_json::to_vec(&bootstrap).unwrap(),
    )
    .unwrap();
    let (genesis, _, _) = abci::l1::verify_genesis_inbox(
        witness.genesis.l1_header.state_root(),
        &witness.genesis.inbox,
        plan.deployment.inbox,
    )
    .unwrap();
    let state = abci::store::AppState {
        schema_version: abci::store::STATE_SCHEMA_VERSION,
        app_version: abci::app::APP_VERSION,
        chain_id: abci::rules::chain_id_for(&plan.deployment.params().unwrap(), 1).unwrap(),
        generation: 1,
        recovery: Some(plan.origin.clone()),
        inbox: plan.deployment.inbox,
        genesis: genesis.clone(),
        last_height: plan.origin.height,
        last_comet_hash: B256::ZERO,
        parent: abci::recovery::recovery_parent(&witness),
        anchor,
        forced_cursor: plan.origin.forced_cursor,
        committees: BTreeMap::from([(
            plan.origin.height / genesis.epoch_len,
            plan.origin.committee.clone(),
        )]),
        val_state: abci::valstate::ValState::genesis(
            plan.origin.height,
            &plan.origin.committee.members.iter().map(|m| (m.pubkey, m.power)).collect::<Vec<_>>(),
        )
        .unwrap(),
    };
    abci::Store::new(store.plan_dir(plan.id()).join("app")).save(&state).unwrap();
    state
}

#[tokio::test]
async fn recovery_activation_committed_crash_window_resumes_without_origin_probe() {
    use crate::recovery::{
        activate::activate_with,
        inspect::{Inspection, validate_stores},
    };
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = native_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let descriptor = installed_descriptor(&store, &plan, &profile);
    store.publish_active(&descriptor, None).unwrap();
    let mut state = initialized_state(&store, &plan, &source).await;
    let header = Header {
        number: 7,
        parent_hash: plan.origin.el_hash,
        extra_data: abci::rules::encode_extra_data(1, plan.origin.l1_number).unwrap(),
        ..Header::default()
    };
    let envelope = abci::envelope::EtnaEnvelope {
        block: ExecutionBlock { header: header.clone(), transactions: vec![] },
        anchor: None,
        committee: None,
        forced: None,
    };
    state.last_height = 7;
    state.val_state = state.val_state.advance(&[]).unwrap();
    state.last_comet_hash = B256::repeat_byte(77);
    state.parent.number = 7;
    state.parent.hash = header.hash_slow();
    abci::Store::new(store.plan_dir(plan.id()).join("app")).save(&state).unwrap();
    let validators = abci::wire::validators_hash(&plan.origin.committee.members).unwrap();
    let mut report = serde_json::json!({"schema":1,"empty":false,"chain_id":state.chain_id,"initial_height":7,"state_height":0,"state_app_hash":plan.origin.el_hash,"state_comet_hash":B256::ZERO,"blockstore_height":7,"validators_hash":validators,"next_validators_hash":validators,"blocks":[{"height":7,"chain_id":state.chain_id,"hash":state.last_comet_hash,"app_hash":plan.origin.el_hash,"parent_hash":B256::ZERO,"transactions":[envelope.encode()]}]});
    let parsed: Inspection = serde_json::from_value(report.clone()).unwrap();
    assert_eq!(validate_stores(&store, &plan, &parsed).unwrap(), Some(state.clone()));
    let mut corrupt = parsed.clone();
    corrupt.blocks[0].hash = B256::ZERO;
    assert!(validate_stores(&store, &plan, &corrupt).is_err());
    corrupt = parsed.clone();
    corrupt.state_app_hash = B256::repeat_byte(9);
    assert!(validate_stores(&store, &plan, &corrupt).is_err());
    // A persisted native state catches up after the app-ahead crash window.
    report["state_height"] = 7.into();
    report["state_app_hash"] = serde_json::to_value(state.parent.hash).unwrap();
    report["state_comet_hash"] = serde_json::to_value(state.last_comet_hash).unwrap();
    assert!(
        validate_stores(&store, &plan, &serde_json::from_value(report.clone()).unwrap()).is_ok()
    );
    std::fs::write(dir.path().join("inspection.json"), report.to_string()).unwrap();
    let mut journal = ActivationJournal::prepared(plan.id());
    journal.active = Some(descriptor);
    journal.phase = ActivationPhase::Settled;
    store.save_journal(&journal).unwrap();
    let mut reader = ReadEngine::new(&source);
    reader.headers.push(header);
    let engine = ProbeEngine { reader, built_on: Mutex::new(vec![]), malformed: false };
    let cancel = async {
        tokio::time::timeout(std::time::Duration::from_secs(10), async {
            loop {
                if std::fs::read_to_string(dir.path().join("children.log"))
                    .unwrap_or_default()
                    .contains("comet:start")
                {
                    break
                }
                tokio::time::sleep(std::time::Duration::from_millis(10)).await;
            }
        })
        .await
        .unwrap();
    };
    activate_with(profile, root, plan.id(), &source, &engine, cancel).await.unwrap();
    assert!(
        engine.built_on.lock().unwrap().is_empty(),
        "genuine committed recovery must never rebuild/rewind c"
    );
}

#[tokio::test]
async fn recovery_activation_private_sessions_fullnode_only_and_incarnation_fail_stop() {
    use abci::app::trust::{RecoveryTrustOrigin, TrustPhase, TrustSnapshot};
    use std::{os::unix::fs::PermissionsExt, sync::Arc};
    use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
    for validator in [false, true] {
        let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
        let source = Source {
            fixture: serde_json::from_str(include_str!("testdata/activation.json")).unwrap(),
            finalized: Mutex::new(VecDeque::new()),
        };
        let mut profile = native_profile(dir.path(), &source);
        let root = dir.path().join("r");
        let plan =
            prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
        let store = RecoveryStore::new(&root);
        let app = store.plan_dir(plan.id()).join("app");
        let o = &plan.origin;
        let snapshot = Arc::new(Mutex::new(TrustSnapshot {
            schema_version: 1,
            session_id: "boot:0".into(),
            chain_id: Some(
                abci::rules::chain_id_for(&plan.deployment.params().unwrap(), 1).unwrap(),
            ),
            generation: Some(1),
            recovery_origin: Some(RecoveryTrustOrigin {
                generation: 1,
                height: o.height,
                l1_number: o.l1_number,
                l1_hash: plan.validate().unwrap().recovery_header.hash(),
                l1_timestamp: o.l1_timestamp,
                el_hash: o.el_hash,
                comet_hash: o.comet_hash,
                forced_cursor: o.forced_cursor,
                committee_hash: o.committee.record.set_root,
            }),
            trust_ready: false,
            syncing: true,
            phase: TrustPhase::Acquiring,
            target: None,
            committed_head: None,
            trusted_consensus_head: None,
            reason: None,
        }));
        let socket = app.join("checkpoint-trust.sock");
        let listener = tokio::net::UnixListener::bind(&socket).unwrap();
        std::fs::set_permissions(&socket, std::fs::Permissions::from_mode(0o600)).unwrap();
        let requests = Arc::new(Mutex::new(Vec::new()));
        let served = snapshot.clone();
        let captured = requests.clone();
        let server = tokio::spawn(async move {
            loop {
                let (stream, _) = listener.accept().await.unwrap();
                let mut stream = BufReader::new(stream);
                let mut line = String::new();
                stream.read_line(&mut line).await.unwrap();
                let request: serde_json::Value = serde_json::from_str(&line).unwrap();
                let op = request["op"].as_str().unwrap().to_owned();
                captured.lock().unwrap().push(op.clone());
                let response = {
                    let mut state = served.lock().unwrap();
                    if op == "begin_session" {
                        state.session_id = "boot:1".into();
                    }
                    format!("{}\n", serde_json::to_string(&*state).unwrap())
                };
                stream.get_mut().write_all(response.as_bytes()).await.unwrap();
            }
        });
        if validator {
            profile.signer = Some(SignerProfile {
                key: dir.path().join("key"),
                state: dir.path().join("hrs"),
                authority: dir.path().join("authority"),
                executable: profile.app.clone(),
                supervisor: profile.app.clone(),
            });
            let denial = app.join("signer-denial.json");
            std::fs::write(&denial, b"{\"sequence\":0,\"session_id\":\"boot:0\"}").unwrap();
            std::fs::set_permissions(&denial, std::fs::Permissions::from_mode(0o600)).unwrap();
        }
        let mut session = None;
        let mut journal = ActivationJournal::prepared(plan.id());
        let reader = ReadEngine::new(&source);
        let first = crate::recovery::status::observation_round(
            &profile,
            &store,
            &plan,
            &source,
            &reader,
            &mut session,
            &mut journal,
        )
        .await;
        if validator {
            assert!(first.is_ok());
            assert_eq!(session.as_deref(), Some("boot:0"));
        } else {
            assert!(matches!(first, Err(RecoveryCommandError::Runtime(_))));
            assert_eq!(session.as_deref(), Some("boot:1"));
        }
        assert_eq!(
            requests.lock().unwrap().iter().filter(|op| op.as_str() == "begin_session").count(),
            usize::from(!validator)
        );
        if validator {
            let denial = app.join("signer-denial.json");
            // New private app session before signer publication: clear old Ready, never rebind.
            journal.phase = ActivationPhase::Trusted;
            journal.progress = Some(ActivationProgress {
                session_id: "boot:0".into(),
                trusted: true,
                committed_height: None,
                trust_target_height: 12,
                landed_height: 12,
                finalized_l1_height: 110,
            });
            snapshot.lock().unwrap().session_id = "boot:1".into();
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::Runtime(_))
            ));
            assert_eq!(session.as_deref(), Some("boot:0"));
            assert_eq!(journal.phase, ActivationPhase::Running);
            assert!(!journal.progress.as_ref().unwrap().trusted);
            std::fs::write(&denial, b"{\"sequence\":0,\"session_id\":\"boot:1\"}").unwrap();
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::Runtime(_))
            ));
            assert_eq!(session.as_deref(), Some("boot:1"));
            assert!(journal.progress.is_none());
            // Signer publication before the sampled app frame: remain closed on the old binding.
            std::fs::write(&denial, b"{\"sequence\":0,\"session_id\":\"boot:2\"}").unwrap();
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::Runtime(_))
            ));
            assert_eq!(session.as_deref(), Some("boot:1"));
            snapshot.lock().unwrap().session_id = "boot:2".into();
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::Runtime(_))
            ));
            assert_eq!(session.as_deref(), Some("boot:2"));
            snapshot.lock().unwrap().session_id = "boot:1".into();
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::SessionChanged)
            ));
            snapshot.lock().unwrap().session_id = "boot:2".into();
            let original = snapshot.lock().unwrap().chain_id.clone();
            snapshot.lock().unwrap().chain_id = Some("foreign".into());
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::Invalid)
            ));
            snapshot.lock().unwrap().chain_id = original;
        } else {
            snapshot.lock().unwrap().session_id = "boot:2".into();
            assert!(matches!(
                crate::recovery::status::observation_round(
                    &profile,
                    &store,
                    &plan,
                    &source,
                    &reader,
                    &mut session,
                    &mut journal
                )
                .await,
                Err(RecoveryCommandError::SessionChanged)
            ));
        }
        assert_eq!(
            requests.lock().unwrap().iter().filter(|op| op.as_str() == "begin_session").count(),
            usize::from(!validator)
        );
        snapshot.lock().unwrap().session_id = "different-boot:0".into();
        assert!(matches!(
            crate::recovery::status::observation_round(
                &profile,
                &store,
                &plan,
                &source,
                &reader,
                &mut session,
                &mut journal
            )
            .await,
            Err(RecoveryCommandError::SessionChanged)
        ));
        // A forged/foreign InitChain origin must not be rearmed even with a new controller.
        session = None;
        snapshot.lock().unwrap().recovery_origin.as_mut().unwrap().el_hash = B256::ZERO;
        let before = requests.lock().unwrap().len();
        assert!(matches!(
            crate::recovery::status::observation_round(
                &profile,
                &store,
                &plan,
                &source,
                &reader,
                &mut session,
                &mut journal
            )
            .await,
            Err(RecoveryCommandError::Invalid)
        ));
        assert_eq!(requests.lock().unwrap()[before..], ["observe"]);
        server.abort();
        let _ = server.await;
    }
}

#[tokio::test]
async fn recovery_activation_rejects_legacy_empty_pv_bundle_and_live_owner_before_probe() {
    use crate::recovery::activate::activate_with;
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = native_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let engine = ProbeEngine {
        reader: ReadEngine::new(&source),
        built_on: Mutex::new(vec![]),
        malformed: false,
    };
    let lease = abci::ownership::acquire_activation(&root, plan.id()).unwrap();
    assert!(matches!(
        activate_with(
            profile.clone(),
            root.clone(),
            plan.id(),
            &source,
            &engine,
            std::future::pending()
        )
        .await,
        Err(RecoveryCommandError::Busy)
    ));
    drop(lease);
    let mut old = plan.clone();
    let mut artifacts: BTreeMap<String, Vec<u8>> = plan
        .artifacts
        .keys()
        .map(|name| (name.clone(), std::fs::read(store.plan_dir(plan.id()).join(name)).unwrap()))
        .collect();
    let mut config: toml::Table =
        toml::from_str(std::str::from_utf8(&artifacts["comet/config/config.toml"]).unwrap())
            .unwrap();
    config.insert("priv_validator_key_file".into(), toml::Value::String(String::new()));
    artifacts
        .insert("comet/config/config.toml".into(), toml::to_string(&config).unwrap().into_bytes());
    old.artifacts =
        artifacts.iter().map(|(name, bytes)| (name.clone(), keccak256(bytes))).collect();
    store.publish_plan(&old, &profile, &artifacts).unwrap();
    assert!(matches!(
        activate_with(profile, root, old.id(), &source, &engine, std::future::pending()).await,
        Err(RecoveryCommandError::Missing("stock local FilePV paths; prepare again"))
    ));
    assert!(engine.built_on.lock().unwrap().is_empty());
    assert!(!dir.path().join("children.log").exists());
}

#[tokio::test]
async fn recovery_activation_accepts_only_exact_prior_supersession_evidence() {
    use crate::recovery::activate::check_prior_halt;
    use abci::recovery::supersession::{SUPERSESSION_FILE, SupersessionEvidence, digest};
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = native_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let mut old = initialized_state(&RecoveryStore::new(&root), &plan, &source).await;
    old.generation = 0;
    old.recovery = None;
    old.chain_id = abci::rules::chain_id_for(&plan.deployment.params().unwrap(), 0).unwrap();
    let bytes = serde_json::to_vec(&old).unwrap();
    let fatal = b"authenticated supersession";
    let evidence = SupersessionEvidence {
        schema: 1,
        chain_id: old.chain_id.clone(),
        previous_generation: 0,
        current_generation: 1,
        inbox: old.inbox,
        state_digest: digest(&bytes),
        fatal_digest: digest(fatal),
    };
    let sidecar = serde_json::to_vec(&evidence).unwrap();
    let app = &profile.app_data_dir;
    std::fs::write(app.join(abci::store::STATE_FILE), &bytes).unwrap();
    std::fs::write(app.join("fatal-evidence.txt"), fatal).unwrap();
    std::fs::write(app.join(SUPERSESSION_FILE), &sidecar).unwrap();
    let latch = serde_json::json!({"schema":1,"kind":"expected-generation-supersession","chain_id":old.chain_id,"previous_generation":0,"current_generation":1,"evidence_digest":digest(&sidecar)});
    std::fs::write(app.join("validator-supervisor.halted"), latch.to_string()).unwrap();
    check_prior_halt(app, &plan).unwrap();
    for changed in ["generic", "wrong-reference", "fatal", "missing"] {
        let path = app.join("validator-supervisor.halted");
        match changed {
            "generic" => std::fs::write(&path, "superseded expected generation").unwrap(),
            "wrong-reference" => {
                let mut bad = latch.clone();
                bad["evidence_digest"] = "bad".into();
                std::fs::write(&path, bad.to_string()).unwrap();
            }
            "fatal" => std::fs::write(app.join("fatal-evidence.txt"), "unrelated fatal").unwrap(),
            _ => std::fs::remove_file(app.join(SUPERSESSION_FILE)).unwrap(),
        }
        assert!(
            matches!(check_prior_halt(app, &plan), Err(RecoveryCommandError::Halted)),
            "{changed}"
        );
        std::fs::write(&path, latch.to_string()).unwrap();
        std::fs::write(app.join("fatal-evidence.txt"), fatal).unwrap();
    }
    assert_eq!(std::fs::read(app.join(abci::store::STATE_FILE)).unwrap(), bytes);
}

#[tokio::test]
async fn recovery_activation_owned_component_exit_stops_remaining_children() {
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let mut profile = native_profile(dir.path(), &source);
    profile.comet.argv=vec!["-c".into(),"import sys,time;from pathlib import Path\np=Path(sys.argv[1])\nwhile not p.exists() or 'app:start' not in p.read_text():time.sleep(.01)".into(),dir.path().join("children.log").display().to_string()];
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let engine = ProbeEngine {
        reader: ReadEngine::new(&source),
        built_on: Mutex::new(vec![]),
        malformed: false,
    };
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        crate::recovery::activate::activate_with(
            profile,
            root.clone(),
            plan.id(),
            &source,
            &engine,
            std::future::pending(),
        ),
    )
    .await
    .unwrap();
    assert!(matches!(result, Err(RecoveryCommandError::ComponentExited)));
    assert!(std::fs::read_to_string(dir.path().join("children.log")).unwrap().contains("app:stop"));
    assert_eq!(
        RecoveryStore::new(&root).load_journal(plan.id()).unwrap().unwrap().blocker,
        Some(ActivationBlocker::ComponentExited)
    );
    assert!(abci::ownership::acquire_activation(&root, plan.id()).is_ok());
}

#[tokio::test]
async fn recovery_activation_origin_state_rejects_mixed_anchor_cursor_or_val_state_before_start() {
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let profile = native_profile(dir.path(), &source);
    let root = dir.path().join("r");
    let plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let state = initialized_state(&store, &plan, &source).await;
    let report: crate::recovery::inspect::Inspection =
        serde_json::from_slice(&std::fs::read(dir.path().join("inspection.json")).unwrap())
            .unwrap();
    assert_eq!(
        crate::recovery::inspect::validate_stores(&store, &plan, &report).unwrap(),
        Some(state.clone()),
        "the installed origin state"
    );
    for change in ["anchor", "cursor", "validator state"] {
        let mut changed = state.clone();
        match change {
            "anchor" => changed.anchor.hash = B256::ZERO,
            "cursor" => changed.forced_cursor += 1,
            // Not the R committee's genesis state, though at the origin height.
            _ => changed.val_state.current.entries[0].priority += 1,
        }
        abci::Store::new(store.plan_dir(plan.id()).join("app")).save(&changed).unwrap();
        assert!(
            crate::recovery::inspect::validate_stores(&store, &plan, &report).is_err(),
            "{change}"
        );
    }
}

#[tokio::test]
async fn recovery_activation_repeated_generation_preserves_historical_supersession() {
    use crate::recovery::activate::{activate_with, check_prior_halt};
    use abci::recovery::supersession::{SUPERSESSION_FILE, SupersessionEvidence, digest};
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let first = Source::new();
    let second = Source {
        fixture: serde_json::from_str(include_str!("testdata/repeated.json")).unwrap(),
        finalized: Mutex::new(std::iter::repeat_n(130, 1000).collect()),
    };
    let profile = native_profile(dir.path(), &first);
    let root = dir.path().join("r");
    let store = RecoveryStore::new(&root);
    let plan1 =
        prepare::prepare(&profile, 1, &root, &first, &ReadEngine::new(&first)).await.unwrap();
    let mut old = initialized_state(&store, &plan1, &first).await;
    for name in [abci::store::STATE_FILE, "recovery-bootstrap.json"] {
        std::fs::remove_file(store.plan_dir(plan1.id()).join("app").join(name)).unwrap();
    }
    old.generation = 0;
    old.recovery = None;
    old.chain_id = abci::rules::chain_id_for(&plan1.deployment.params().unwrap(), 0).unwrap();
    let raw = serde_json::to_vec(&old).unwrap();
    let fatal = b"authenticated supersession 0 to 1";
    let evidence = SupersessionEvidence {
        schema: 1,
        chain_id: old.chain_id.clone(),
        previous_generation: 0,
        current_generation: 1,
        inbox: old.inbox,
        state_digest: digest(&raw),
        fatal_digest: digest(fatal),
    };
    let sidecar = serde_json::to_vec(&evidence).unwrap();
    let latch=serde_json::to_vec(&serde_json::json!({"schema":1,"kind":"expected-generation-supersession","chain_id":old.chain_id,"previous_generation":0,"current_generation":1,"evidence_digest":digest(&sidecar)})).unwrap();
    let originals = [
        (abci::store::STATE_FILE, raw),
        ("fatal-evidence.txt", fatal.to_vec()),
        (SUPERSESSION_FILE, sidecar),
        ("validator-supervisor.halted", latch),
    ];
    for (name, bytes) in &originals {
        std::fs::write(profile.app_data_dir.join(name), bytes).unwrap();
    }
    let plan2 =
        prepare::prepare(&profile, 2, &root, &second, &ReadEngine::new(&second)).await.unwrap();
    assert!(plan2.origin.l1_number > plan1.origin.l1_number);
    assert_eq!(plan2.origin.height, plan1.origin.height);
    for (attempt, plan, source) in [(0, &plan1, &first), (1, &plan2, &second)] {
        let engine = ProbeEngine {
            reader: ReadEngine::new(source),
            built_on: Mutex::new(vec![]),
            malformed: false,
        };
        let cancel = async {
            tokio::time::timeout(std::time::Duration::from_secs(10), async {
                loop {
                    if std::fs::read_to_string(dir.path().join("children.log"))
                        .unwrap_or_default()
                        .matches("comet:start")
                        .count() >
                        attempt
                    {
                        break
                    }
                    tokio::time::sleep(std::time::Duration::from_millis(10)).await;
                }
            })
            .await
            .unwrap();
        };
        activate_with(profile.clone(), root.clone(), plan.id(), source, &engine, cancel)
            .await
            .unwrap();
        assert_eq!(store.load_active().unwrap().unwrap().plan_id, plan.id());
        for (name, bytes) in &originals {
            assert_eq!(std::fs::read(profile.app_data_dir.join(name)).unwrap(), *bytes);
        }
    }
    for negative in ["future", "domain", "generic", "tamper"] {
        let mut changed = evidence.clone();
        match negative {
            "future" => changed.current_generation = 3,
            "domain" => changed.chain_id = "foreign".into(),
            "generic" => {
                std::fs::write(
                    profile.app_data_dir.join("validator-supervisor.halted"),
                    "expected supersession",
                )
                .unwrap();
            }
            _ => {
                std::fs::write(profile.app_data_dir.join("fatal-evidence.txt"), "changed").unwrap();
            }
        }
        if ["future", "domain"].contains(&negative) {
            let bytes = serde_json::to_vec(&changed).unwrap();
            std::fs::write(profile.app_data_dir.join(SUPERSESSION_FILE), &bytes).unwrap();
            let mut latch: serde_json::Value = serde_json::from_slice(&originals[3].1).unwrap();
            latch["current_generation"] = changed.current_generation.into();
            latch["chain_id"] = changed.chain_id.into();
            latch["evidence_digest"] = digest(&bytes).into();
            std::fs::write(
                profile.app_data_dir.join("validator-supervisor.halted"),
                latch.to_string(),
            )
            .unwrap();
        }
        assert!(
            matches!(
                check_prior_halt(&profile.app_data_dir, &plan2),
                Err(RecoveryCommandError::Halted)
            ),
            "{negative}"
        );
        for (name, bytes) in &originals {
            std::fs::write(profile.app_data_dir.join(name), bytes).unwrap();
        }
    }
}

#[path = "supervisor_activation_tests.rs"]
mod supervisor_activation_tests;

#[tokio::test]
async fn recovery_activation_current_halt_stops_owned_children_and_preserves_evidence() {
    use crate::recovery::activate::activate_with;
    for filename in
        ["validator-supervisor.halted", "fatal-evidence.txt", "generation-superseded.json"]
    {
        let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
        let source = Source::new();
        let mut profile = native_profile(dir.path(), &source);
        profile.app.argv[1] = profile.app.argv[1].replace(
            "record('start')",
            &format!("record('start')\nfrom pathlib import Path\nPath(sys.argv[sys.argv.index('--data-dir')+1], {filename:?}).write_bytes(b'new current fatal evidence')"),
        );
        let root = dir.path().join("r");
        let plan =
            prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
        let engine = ProbeEngine {
            reader: ReadEngine::new(&source),
            built_on: Mutex::new(vec![]),
            malformed: false,
        };
        let result = tokio::time::timeout(
            std::time::Duration::from_secs(5),
            activate_with(
                profile,
                root.clone(),
                plan.id(),
                &source,
                &engine,
                std::future::pending(),
            ),
        )
        .await;
        assert!(
            matches!(result, Ok(Err(RecoveryCommandError::Halted))),
            "new {filename}: {result:?}"
        );
        let store = RecoveryStore::new(&root);
        assert_eq!(
            std::fs::read(store.plan_dir(plan.id()).join("app").join(filename)).unwrap(),
            b"new current fatal evidence"
        );
        let journal = store.load_journal(plan.id()).unwrap().unwrap();
        assert_eq!(journal.blocker, Some(ActivationBlocker::SafetyHalt));
        assert!(journal.progress.is_none_or(|p| !p.trusted));
        assert!(abci::ownership::acquire_activation(&root, plan.id()).is_ok());
        let log = std::fs::read_to_string(dir.path().join("children.log")).unwrap();
        assert!(log.contains("app:stop"));
        assert!(log.contains("comet:stop"));
    }
}

#[tokio::test]
async fn recovery_process_specifications_encode_canonical_signer_deployment() {
    let dir = tempfile::tempdir_in(short_temp_parent()).unwrap();
    let source = Source::new();
    let mut profile = configured_profile(dir.path(), &source);
    profile.role = NodeRole::Validator;
    profile.signer = Some(SignerProfile {
        key: dir.path().join("key.json"),
        state: dir.path().join("state.json"),
        authority: dir.path().join("authority"),
        executable: profile.app.clone(),
        supervisor: profile.app.clone(),
    });
    let template = profile.comet_home.join("config/config.toml");
    std::fs::write(
        &template,
        std::fs::read_to_string(&template)
            .unwrap()
            .replace("priv_validator_laddr = ''", "priv_validator_laddr = 'tcp://127.0.0.1:26659'"),
    )
    .unwrap();
    install_transport_key(&profile);
    let root = dir.path().join("r");
    let mut plan =
        prepare::prepare(&profile, 1, &root, &source, &ReadEngine::new(&source)).await.unwrap();
    let store = RecoveryStore::new(&root);
    let config = std::fs::read(store.plan_dir(plan.id()).join("comet/config/config.toml")).unwrap();
    // Isolate command serialization with an alphabetic address. This is not an authenticated
    // activation: the command compiler takes the already validated caller-owned plan.
    let inbox = "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512";
    plan.deployment.inbox = inbox.parse().unwrap();
    let configuration = store.plan_dir(plan.id()).join("comet/config");
    std::fs::create_dir_all(&configuration).unwrap();
    std::fs::write(configuration.join("config.toml"), config).unwrap();
    let installed = crate::recovery::install::binding(&profile, plan.id()).unwrap();
    std::fs::create_dir_all(store.plan_dir(plan.id()).join("app")).unwrap();
    std::fs::create_dir_all(&installed.home).unwrap();
    let specs =
        crate::recovery::process::specifications(&profile, &store, &plan, &installed).unwrap();
    let supervisor = &specs[1].executable.env;
    // ETNA_COMET_COMMAND_JSON is Comet's complete argv: the supervisor adds no --home.
    let comet = std::iter::once(profile.comet.program.display().to_string())
        .chain(profile.comet.argv.iter().cloned())
        .chain(["--home".into(), installed.home.display().to_string()])
        .collect::<Vec<_>>();
    assert_eq!(
        serde_json::from_str::<Vec<String>>(&supervisor["ETNA_COMET_COMMAND_JSON"]).unwrap(),
        comet
    );
    assert_eq!(supervisor["ETNA_INBOX"], inbox);
    assert_eq!(supervisor["ETNA_L1_CHAIN_ID"], plan.deployment.l1_chain_id.to_string());
    assert_eq!(
        supervisor["ETNA_CHAIN_ID"],
        abci::rules::chain_id_for(&plan.deployment.params().unwrap(), 1).unwrap()
    );
}
