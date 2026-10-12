# Parent-anchor committee implementation plan

> Execute with superpowers:subagent-driven-development, sequential fresh implementers and task review gates, then one final cross-repo review. User approved the written spec with 可以. Do not ask for another design/implementation/push confirmation.

**Goal:** Update PR22280 and PR22286 to derive incoming committees from the committed switch-parent anchor, retaining authenticated arbitrary batch cuts, recovery, back-pressure and generation.

**Architecture:** Approved spec docs/superpowers/specs/2026-10-12-etna-parent-anchor-committee-design.md, commit1986b9a48010ab9b62a778f9003d2532a619bf52. Runtime snapshot is state.anchor.number at H(t)-2. Starting lander sets obtain that number from authenticated EL ancestors at D(t)=H(t)-3; historical registry witnesses may prove under a later authenticated root covering the number. Keep existing registry checkpoints and complete snapshot verification.

**Stack:** Rust1.95/Alloy/CometBFT0.40, Solidity0.8.30/Foundry/pnpm, pinned Docker images.

## Global constraints

- Client source baseline367466179027a88d599e780dd8954590f17fd2de; current docs-onlyHEAD1986b9a48. Worktree /Users/davidcai/.codex/worktrees/pr22280-review-oct11/taiko-mono;branchcodex/pr22280-genesis-simplification;remote feat/taiko-client-rs-abci.
- Protocol baseline1a964fb41275d2717d570b2b2bb7bf914cc94b98. Worktree /Users/davidcai/.codex/worktrees/etna-fixed-cutoff-protocol/taiko-mono;branchcodex/etna-fixed-cutoff-protocol;remote codex/protocol-etna-contracts.
- H(t)=1+t\*epochLenL2;S(t)=H(t)-2;D(t)=H(t)-3 for t>=1 with checked arithmetic. Committee0 retains explicitgenesisCutoff/bootstrap278.
- Runtime snapshot exactly committed parent.anchor.number/root atS;never currentcandidate/newfinalizedhead. Evaluate active/exit at snapshot number, not registry mutation checkpoint number.
- Keep membership/power/heartbeat/MEM08 implementations and exemptions0/1/2;heartbeatlookahead2 stays. Preserve existing full-proof/exact-slot/address/root/record checks. No implicitempty-setfallback.
- Preserve cap height-checkpoint<=dMax-marginV and L>=U+3, generation IDs/domains/supersession, canonical/finality checks, deterministic no-L1 Finalize/replay, hash-pinned latest snapshot retry, durable nonce/receipt/backlog behavior.
- No new per-epochmapping/set/publication/land gate, realguest, snapshots, slashing, recoverybootstrap or registry lifecycle redesign.
- Config exact9words ETNA_PARENT_ANCHOR_V1,L2chain,registry,vpUnit,sMin,nMax,heartbeatWindow,uint64(2),uint8(1).288bytes. Remove grid/lag config.
- Envelope3,journalschema3,TAIKO_ETNA_LAND_V5 with unchanged15word480byte order/four-fieldLandInput/helperABI. Recordencoding1,outercompleteblockcodec1. OldV2/V4 histories/states/jobs reject, never discard/resign/cancel signednonce.
- Keep storage meanings258/268/269/270-271/272-274/278/279 and existing contractidentity/blob/reference/checkpoint/SignalService/rollback checks. Regenerate artifacts from exact newprotocolHEAD;no hand edits.
- EveryproductionRustsymbol documented;no generatedbindings edits. SolidityfullinterfaceNatSpec/implementationinheritdoc. Allsources/testsonlyephemeralharnesskeys;neverreadSecretvalues.
- Workers commit onlyownedpaths and neverpush. Rootcoordinatespins/docs andpushesexistingPRbranchesonlyafterchecks/reviews. Preserve maincheckout unrelated.claude deletions andunknown.build.

## Task P1: Protocol V5 and parent-anchor config/guest contract

Ownership: packages/protocol/contracts/layer1/etna/iface/IEtnaInbox.sol, impl/EtnaInbox.sol and correspondinglayoutcomment; Etna test/deployscript/helpers as needed; EtnaREADME and Etna-onlygas/layout output. Root owns clientfixtures/topdocs. Act as the required solidity-tester for all Foundry verification.

1. Add meaningful RED for rejecting V4 digest and fixed-cutoff config opening where hashvectors/docs encode old11words; pin nine-word newconfig and exactV5 vector independently computed with ethers. Do not describe mere renaming compilation errors as behavioralRED.
2. Change statementdomainV4->V5, config/authoritativeguest documentation and vectors. Keep ABI/storage/bootstrap/checkpoint/generation/backpressure boundaries. Guest must derive starting/current/pending sets from authenticated D(t) EL ancestry and explicit historical registry snapshot; runtime switch proof exactparentroot.
3. Run focusedEtna RED/GREEN and field/domain/blob-order/identity/caller/rollback checks. All15wordpreimage mutations remain;config9word expected288B,statement480B,input128B.
4. Run establishedformat/solhint, fullpnpmtest, layout andgasverification usingtemp/archiveoutputs toavoid unrelatedwhole-repogeneratornoise. Preserve non-Etna outputs. Dependencies alreadyinstalledoffline; verify beforeFoundry. Coverage remainsknownblockedbyunchangedAutomata;attemptagainonlyifnewchangewarrantsit,no unsupportedpercentclaim.
5. Self-review, normalcommitownedpaths andreport exactSHA/counts/ABI/vectors/logs. No push.

Root after P1 cleanreview: regenerateclientinterface/artifacts with script/gen_lander_artifacts.sh,pin generator/PROTOCOL_REVISION/provenance,verify6artifact/sourcehashes/canonicalABI. Commit rootownedfixtures before P2 starts tokeep one indexwriter.

## Task P2: ABCI parent snapshot, simplified config and deterministic switch recovery

Ownership: crates/abci,crates/test-harness,bin/client commandsabci_genesis.rs/abci_committee_record.rs andassociatedonlyABCI flag/config CLIconsumers. No lander/topdocs/generatedfiles.

1. Behavioral RED: parent1010 versus1020 deliberately yieldsdifferent committee when effectiveactivation/exitchanges; sameparent deterministic; newblockanchor1030 mustnotreplaceparent1010 proofroot/snapshot. Keep explicitgenesiscut unchanged.
2. Remove fixed_cutoff and obsolete lag/grid helpers/config/errors/overrides/tests. runtimeverify_committee_witness uses parent.number as snapshot andexactparent.root. Retain/reuse explicit-snapshot discovery/verifier for genesis/hostjobs, with coveragecheck atcallerboundary.
3. Introduce checked public Schedule::derivation_parent_height(target_epoch)->Option<u64>:t0None; t>=1 checkedH(t)-3. Export ifrequiredbylander. ExistingS/H+2 behavior stays.
4. Implement exact9wordconfig hash/newtag;updategenesisCLI report/opening/fakeharness defaults. Persistedconfigopeningcheck remains. Envelope3 rejectsV2. Completeentry/heartbeat/MEM08/validator_updates algorithms stayidentical.
5. Preserve candidateanchor/status/gen/cap ordering, optionalproofmatrix, derived-before-update finalizer,pending/Commit persistence andno-L1 replay. Add meaningful switch-height crash-before/afterCommit replay assertions comparingresponses/sets/headerhashes.
6. Run focused RED/GREEN, ABCI+harnesslib/alltargetdocclippy,fmt,ABCI9Dockerincludingnewversion switch/crash/loststate/BP/gen. Avoid claimingworkspacepass until P3 consumersupdated. Preserve anyreal failures/retries inreport. Normalcommitownedpaths only,no push.

Publichandoff to P3: runtimeverify signature remains; explicit verify_committee_witness_at_cutoff stays; checkedDhelper asabove; ChainParams grid/lag removed,newhash9words; GenesisRecordfieldcommittee_config_hash stays; Envelope3.

## Task P3: Authenticated derivation history for lander arbitrary cuts

Ownership: crates/lander excludingrootownedartifactgeneration/pinfiles duringagreedwindows; relevantlanderCLI flags/commands/tests/support. Root ownstopREADME/CHANGELOG/AGENTS/artifactscript/pin.

1. Add RED mid-epochbatchbeginningafterS where parentanchor moved sinceD, checkpointH-1pendingnextset, forged/missing/reordered/wrongheight/generation/anchor ancestry. Existingfixed shortcut should fail the intendedparentderived case.
2. Add a smallpure historymodule with namedinputs. VerifycheckpointELheaderagainstcontractboundp/hash,descending consecutiveELhashlinks to minimal requiredD(current/nextepoch) and p-1 forgptimestamp. Derivation snapshot comesonlyfromauthenticatedD headerextraData;nevertrustahint. CheckedboundatmostL+2links,existingI/O/journalbounds,preciserequiredheighterrors. No fullpriortransaction/commitre-execution.
3. Extendread-onlysourceinterface for minimal ELancestorheaders; fetchfrompublicELRPC/Cometenvelopes butverifylinks. Parent/genesis handling stays. Retain history inPreparedBatch andserialproofrequest.
4. Startingcurrent/nextsets: usehistoricallyauthenticatedsnapshotnumber,provecompletehistoricalregistrycheckpoint/entriesunderauthenticatedprovinganchorwithnumber>=snapshot. Keep everyprovingL1root inreferenceancestry. InsidebatchderiveonlyatSunderactualcommittedparentroot,comparetoanycachedcontext. Deduplicateepochswithoutlosingderivationprovenance.
5. Preservecheckpoint/current/previous/next certificates, body/partset/EL ancestry,strict>2/3distinctsigners,nextValidatorHashatH-1/H. Removeautodiscoveryshortcutusingnewercheckpointanchorasanticipatedsnapshot. Authenticatebase-feegrandparenttimestampfromheaderchain.
6. V5same15wordinputorder,newcfgRoot/vectors;schema3 guards beforeoldjobdecode andpreservesV4idle/pendingfilebyte-for-byte. Keep waittimer/minimum/pressure/switchflush/bloblimits/hash-pinnedsnapshotreorg/receipt/identicalnonce retries.
7. Realcontractfixtures exerciseproductionbuilderandELhistory aroundallcuts. Runfinal justfmt/bothclippy/justunit/all22Docker;retain exactcounts/logs/anyretries. Self-review andnormalcommitownedpaths,no push.

## Task P4: Root integration, final review and both pushes

1. UpdateCLI/topdocs/CHANGELOG/AGENTS/sourcepins aroundparentderivedsnapshot/ELhistory/genesisexception/lessnotice/emptyparenthalt/newversions/no realguest. Keepsourcefixturesreproducible.
2. Verifyfinalprotocol/CLI/crosslanguageconfig/statementencoding,source/artifacthashes andrequiredchecks. Ifsourcechangesafterchecks reruncoveringchecks;no unrelatedrepeat.
3. Generateimmutableper-taskpackagesfromrecordedbases,task-spec+qualityreviewaftereach. Finalfreshcrossreporeviewer checksparentselection,frozenDhistorybinding,H+2,newversioncrash/replay,BP/gen preserved,SourceL1reorgrace/noncejournals. FixallCritical/Important andreruncoveringtests/review.
4. ConfirmremotePRheadsandlocalancestry/scope. Non-forcepushprotocolHEADtocodex/protocol-etna-contracts,clientHEADtofeat/taiko-client-rs-abci. VerifyGHSHAs,updateexistingPRbodieswithfinalimplementation/counts/versionboundaries/materiallimits. Keepworktreesforfollowup,preserveunrelatedstate.

## Durable execution and reports

Currentgoal ledger .superpowers/sdd/progress.md supersedes previousfixedcutoffcompletedgoal (archivedbeforeoverwrite). Taskbriefs/reports /private/tmp/etna-parent-anchor-task{1,2,3,4}-{brief,report}.md; reviewersreadapprovedspec,taskbrief,claimreport andimmutablepatch,notentirecontrollerhistory.

Baselineevidence from exactunchangedsourceheads:703workspace+58no-defaultprotocol+2docs;latestreadonlyreview196targetedunits+22/22Docker;protocol761passed/14expectedRPCforkskips/125Etna. Do not relabel historical checks as new postchangeverification. Nativeworktreesalreadyisolated;reuse. Standardimplementationmodelgpt-6.1-solhigh;architecture/finalreviewgpt-6-astrahigh withfreshforknone. Sequentialimplementationworkers,independentreadonlyreviews/testcheckswherecleanlyseparated.
