# Etna Lean 4 Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking. This document is a plan for review, not authorization to commit, push, or deploy.

**Goal:** 为 FI、委员会切换和 land() 交付 Lean 4 定理、与真实实现的对应检查及配对 CI，并精确报告实现证明的覆盖边界。

**Architecture:** 一个 repo-root Lean package 提供公共数据模型、三个证明域和组合定理。客户端提取生产纯内核，经 Charon/Aeneas 生成 Lean 并证明 refinement；合约阶段先完成操作模型证明和真实合约 conformance，字节码 refinement 单独验收。CI 同时检查证明、源代码/生成结果对应关系和两个 PR 的实际配对版本。

**Tech Stack:** Lean 4、Mathlib、Lake、Charon/Aeneas Lean backend、Python 3 JSONL orchestration、Rust/nextest、Foundry、GitHub Actions。

**Spec:** [Etna Lean 4 Verification Design](../specs/2026-10-15-etna-lean4-verification-design.md)

## Global Constraints

- 基线：protocol `41241d5e6440c2ab244ccfdf572d1af8016f70c6`；client `2d00eb054d767093742af6af6a061d30a3d2d118`。
- Lean `leanprover/lean4:v4.35.0-rc4`；Aeneas `673f9e30e1e2a81b355df9a9550168e672a10d4e`；Mathlib `1f414401f69059aa7eead47b53ee40bd38455eeb`；Charon `a5276d59516b6e7dc519441e244399ab8d429107`；extractor Rust `nightly-2026-09-17`。Task 1 写入 lock 并校验固定来源，不浮动。
- 生产 Rust 保持 1.95；Solidity 保持 0.8.30、optimizer runs 200、EVM Osaka 和当前 via-IR 设置。
- 保持 envelope v5、payload v4、journal schema 8、APP_VERSION 2、V6 十八词 statement、六字段 LandInput 和 storage layout。
- 不允许 sorryAx、自定义 axiom 或 native_decide 信任进入要求通过的定理；标准 axiom allowlist 为 propext、Classical.choice、Quot.sound。
- 不改 registry/journal，不实现 guest，不改变 FI 或委员会协议语义；不为适配提取器删除认证、执行检查或生产 opcode。
- 使用独立工作区，不恢复或覆盖当前 checkout 已有的 `.claude` 删除项。阶段完成后根据该阶段实际改动运行仓库要求的测试；本计划文档编写不运行运行时测试。

## Review Focus

- due 边界、u64 极值、空 admission 与 omitted preimage 不同，不能把 hash 缺失解释为无效交易。
- singleton RPC 的失败或错误上下文不能成为 skip；hot cache 的同高度不同 parent/proposal 不能命中。
- D/S/H 切分、epoch 0、最短 epoch、checked height overflow 和严格 2/3 阈值分别覆盖。
- verifier/SignalService/recipient 任一点失败，回滚范围包含外部效果和日志；支付模型不能假设 callback 后 recipient 最终余额必增 fees。
- 任一 PR 前移、fixture 过期、生成翻译被手改、定理缺失或前提被弱化，必须被对应检查或人工 proof review 拦住。

## 交付和文件归属

| 交付组       | 归属                         | 文件范围                                                                                                                                         |
| ------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| F 公共底座   | 两 PR 共用的基础提交，先落地 | `formal/etna/{lean-toolchain,lakefile.toml,lake-manifest.json,tools.lock.json,Etna/Common/,scripts/,manifests/core.json,README.md}`              |
| C 客户端证明 | 22280                        | `formal/etna/Etna/{FI/,Committee/,Refinement/Rust/}`、`Check/{FI,Committee}.lean`、client manifest；新 `crates/etna-consensus-core` 和下列调用点 |
| P 合约证明   | 22286                        | `formal/etna/Etna/Landing/`、`Check/Landing.lean`、contracts manifest；Foundry conformance harness/tests                                         |
| I 组合与 CI  | 公共集成提交，两边验证       | `Etna/Integration/Composition.lean`、integration manifest、paired workflow/scripts、coverage/provenance report                                   |

F 必须先提供给两条分支，避免复制公共规格；C/P 各自可评审；I 在配对 checkout 中组合它们。现有两个大 PR 可以保留原有功能范围，证明增量按这些提交组交付。本轮仅生成计划，不创建这些提交或 PR。

## Task 1：锁定工具和证明等级

**Files:** 创建 F 中的工具文件、`scripts/toolchain_smoke.sh`、`scripts/audit_proofs.py`、`Audit.lean`、`manifests/core.json`、`Etna/Common/Words.lean`、`Etna/Common/Assumptions.lean`。

**Interfaces:** 共同定义 Word48/64/256、`Failure`、`Blocked`、`Accepted`、`ConsumedIndex`、`BatchSummary`、定理 ID/assumption/bridge-level manifest；每个正式 theorem ID 的完整类型必须进入审计。其他任务只依赖这里的位宽与认证事实接口。

- [ ] 校验固定 Aeneas 的 `charon-pin`、固定 Charon 的 `rust-toolchain` 与上述版本相等，写入不可浮动的 `tools.lock.json`；创建 Lake package 并锁定 Mathlib 与传递依赖。
- [ ] 用该固定 Aeneas 的官方最小 safe-Rust 示例完成 Charon→LLBC→Lean 的工具健康检查；它只证明工具能启动，不给 Etna implementation-proved。生产 `is_due` 和 schedule 的兼容性验收属于 Task 2，避免任务依赖倒置。
- [ ] 对当前 `land()` 的实际编译产物生成 opcode、CALL/DELEGATECALL、slot、compiler-setting inventory，对照固定 EVMYulLean/Clear 的能力记录 coverage gaps；不通过改成 via-IR 或删 opcode 取得成功。
- [ ] 提供 `scripts/audit_proofs.py`，按完整 manifest 生成 `Audit.lean` imports/检查命令，逐个检查 theorem 存在、完整类型、显式前提和传递 axioms；测试“删 theorem”“sorry”“额外 axiom”“遗漏 import”均失败。
- [ ] 验证 `lake build` 和 `lake env lean Audit.lean` 成功；负例必须返回非零退出码。Aeneas smoke 不通过时保留 implementation-refinement=pending，先推进独立的协议模型；不宣称 Rust 已证明。

**验收：** 工具版本可重复解析和构建；报告分别存在 spec、Rust refinement、Solidity refinement、conformance 四个状态。Solidity 工具限制是明确 gap，不是隐藏假设。

## Task 2：提取实际生产 Rust 内核

**Files:** 创建 `packages/taiko-client-rs/crates/etna-consensus-core/{Cargo.toml,src/lib.rs,src/forced.rs,src/schedule.rs,src/transition.rs}`；修改 workspace Cargo 文件、`crates/abci/Cargo.toml`、`crates/lander/Cargo.toml` 及 `abci/src/{forced.rs,schedule.rs,engine/forced.rs,app/validate.rs,app/finalize.rs}`、`lander/src/validate.rs` 的相关调用。

**Interfaces:** 生产 core 使用整数、enum 和普通结构，不依赖 Alloy/Tokio/CometBFT；导出 `is_due(timestamp: u64, delay: u64, anchor_timestamp: u64) -> bool`、`classify_forced(facts: ForcedFacts) -> Result<ForcedDecision, ForcedError>`、`resolve_forced(decision: ForcedDecision, outcome: SingletonOutcome) -> Result<Option<u64>, ForcedError>`、`advance_cursor(cursor: u64, consumed: Option<u64>) -> Result<u64, ForcedError>`、checked schedule 函数、`transition_committee(state: CommitteeState, facts: BlockFacts) -> Result<(CommitteeState, Vec<Update>), CommitteeError>` 和 `has_strict_quorum(signed_power: u128, total_power: u128) -> bool`。范围约束和乘法失败路径必须显式建模。外部 wrapper 负责 MPT、raw bytes/canonical/hash、EL 构建、signature 与 protobuf，输入事实来源写入 manifest。

`classify_forced` 不把 NeedsSkip 当消费；`resolve_forced` 消费 completed singleton outcome；`advance_cursor(cursor, consumed)` 要求 consumed index 与 cursor 一致。生产调用点必须走这些函数，不能留一套原算法只让证明 crate 调用另一套。

- [ ] 在原源码基线上导出行为 corpus，覆盖 FI-01..09、COM-01/04/07；记录 expected decision、error 类别、consumed index、cursor、updates。测试不得将新实现同时作为 expected oracle。
- [ ] 把实际无 I/O 分支移动到新 core，保持错误和可表示域语义；保留 hash/decoder/async 工作在原适配层。
- [ ] 用同一 corpus 比较重构前后，覆盖 due ±1、u64 极值、8192/8193、空/省略 preimage、wrong index、retained/error/timeout、epoch 0、L=3 和 schedule overflow。
- [ ] 从 core 重新运行 Charon/Aeneas；记录每个 generated definition 对应的 Rust 符号、工具版本和 source digest。缺失函数或未证明 extern 不得给出 implementation-proved。
- [ ] 完成范围检查后运行 `just fmt && just clippy && just unit && just test`；生成结果重跑两次应字节一致。需要引入 extraction helper 时，共享相同生产源码，不能复制算法。

**验收：** 生产节点和 lander 使用同一 core；行为 corpus 不变；提取输出可重现。该任务本身还不声称 refinement theorem 已完成。

## Task 3：FI 定理与 Rust refinement

**Files:** 创建 `Etna/FI/{Model,Proofs}.lean`、`Etna/Refinement/Rust/Forced.lean`、`Check/FI.lean`、`corpus/fi.jsonl`、client manifest；扩展 `abci/src/forced/tests.rs`、`engine/forced.rs` 内测试、`app/tests/{process,finalize}.rs`、`crates/abci/tests/forced_calldata.rs` 和 lander 对应测试。

**Interfaces:** Lean `classify : ForcedFacts → Except Failure Decision`；`resolve : Decision → SingletonOutcome → Except Failure (Option ConsumedIndex)`；`advance : Cursor → Option ConsumedIndex → Except Failure Cursor`。`SingletonOutcome` 必须区分 unavailable、retained、malformed、wrongContext 与 completedEmpty；认证事实和 candidate identity 是可检查输入，不是默认 true。

- [ ] 写 FI-01..09 的 theorem statements 和参考行为。加入明确的可满足性例子：普通块、pre-due include、due invalid skip、due canonical completedEmpty skip 四类都有有效输入。
- [ ] 证明 classify/resolve 的全部分支；用位宽引理证明 due 和 cursor arithmetic；归纳证明任意有限有效 block list 的消费计数和不越界。
- [ ] 在生成的生产函数上证明 `rust_is_due_refines`、`rust_classify_refines`、`rust_resolve_refines`、`rust_advance_refines`。未覆盖的 byte parser/MPT/Engine adapter 作为具名 proof boundary 出现在每项报告。
- [ ] 对真实 Process/Finalize/Commit/reopen 比较同一 proposal/context 的 hot/cold trace；加入 context/proposal 改变后的 cache miss、历史状态缺失、cancel、错误 header、omitted preimage 与真实空 admission。
- [ ] mutation：NeedsSkip 未经完成即推进、把 error 当 empty、把 due 的 >= 改为 >、只删 hot 或 cold 消费，各自必须使 theorem/refinement 或对应测试失败；恢复后通过。

**验收：** FI 所有 ID 有定理；纯内核 implementation proof 和 async-wrapper conformance 分开标记。测试报告不能把后者冒充形式化证明。

## Task 4：委员会切换定理与 Rust refinement

**Files:** 创建 `Etna/Committee/{Schedule,Transition,Proofs}.lean`、`Etna/Refinement/Rust/Committee.lean`、`Check/Committee.lean`、`corpus/committee.jsonl`；扩展 `abci/src/schedule.rs` 测试、`app/tests/committee_witness.rs`、`crates/abci/tests/{epoch_switch,restart,back_pressure}.rs`、`lander/src/batch.rs` 与 `validate.rs` 测试。

**Interfaces:** `H(L,t)=1+t*L`，`D=H−3`，`S=H−2`；`step : CommitteeState → AuthenticatedBlockFacts → Except Failure (CommitteeState × Updates)`；`replay` 为 step 的 fold。opaque root/hash 参与精确相等检查，`derive(snapshot)` 的确定性作为具名前提，本期不重证明完整选举排序。

- [ ] 写 COM-01..07 statements，包括 epoch 0 特例、u64 checked 域、严格 quorum 和最短 L；为合法切换构造非空模型例子，避免证明前提不可满足。
- [ ] 证明 schedule/update/activation 和 back-pressure 不等式；证明 parent anchor 的来源唯一且不能用 candidate 新 anchor 替代。
- [ ] 对 replay 归纳证明 `replay(xs ++ ys,s)=replay(ys,replay(xs,s))` 的成功分支，并加入证书/parent witness 的完整前提；从而得到任意 batch cut 一致性，而不只枚举五个 cut。
- [ ] 在实际提取的 schedule/transition/quorum reducer 上证明 refinement；验签、snapshot 认证、Comet h+2 行为分别保持显式边界。
- [ ] 扩展 production trace：D/S/S+1/H 所有切分、不同 snapshot root、等于 2/3、重复 signer、nil/absent、wrong chain/block、空 incoming、conflicting record、crash/replay 和不同 generation。
- [ ] mutation：把 H−3 改为 candidate anchor、提前/推迟一个高度激活、把严格 >2/3 改为 >=、遗漏 pending committee，必须触发对应 gate。

**验收：** COM 所有 ID 完成；任何完成时间/可用性结论均不超出前提。不要声称整个 cold Finalize 无网络依赖。

## Task 5：land 操作模型、定理和真实合约对应检查

**Files:** 创建 `Etna/Landing/{Statement,Model,Proofs}.lean`、`Check/Landing.lean`、`corpus/landing.jsonl`、contracts manifest；创建 `packages/protocol/test/layer1/etna/EtnaInboxLeanConformance.t.sol`；按需扩展现有 `EtnaInboxLand.t.sol`、`EtnaInboxForcedInclusion.t.sol`。不修改生产 ABI/layout/编译设置。

**Interfaces:** `encodeStatement : LandStatement → Vector Byte 576`；`execLandSteps : World → LandInput → ExternalOutcomes → TentativeResult`；`runTransaction : World → TentativeResult → TransactionResult`。World 覆盖 Inbox、queue、SignalService、transfer/log effects 和 reentrancy guard；外部调用失败保持不同阶段信息。

- [ ] 证明 LAND-01..06 和 LAND-08。fee 求和基于 uint48 条目数和 uint64 gwei fee，显式证明 sum 与乘 10^9 不溢出 uint256；reference 覆盖 age=256/257/8191/8192、当前/未来块、零/错误长度历史响应，blob 覆盖空列表和顺序变化。
- [ ] 对十八词 preimage 证明字段编码的可逆/不遗漏性质；保留对域、地址、generation、config、ordered blobs、queue heads、recipient 的独立 mutation。hash 抗碰撞前提不混入无条件编码定理。
- [ ] 建立逐步骤 source map：每个 require、storage write、外部 call、emit 都有对应 model step；验证失败发生在 tentative 写入之后也会回滚，而不只测试入参早退。
- [ ] Foundry 在实际 EtnaInbox/proxy 上运行同一 JSONL corpus，输出 head/checkpoint、事件、transfer target/amount、SignalService 状态和 revert 分类；与 Lean 结果比对。
- [ ] 覆盖 head 超 tail/回退、消费多于块数、无进展、过大 batch、uint48 边界、零 recipient、copied landing、verifier/SignalService/payment revert、recipient/verifier 重入、blob 顺序及身份替换。
- [ ] 按 `packages/protocol/CLAUDE.md` 的 solidity-tester 角色要求执行协议测试：`FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/*.t.sol'`；运行 scoped fmt/lint，确认 ABI/layout/非注释生产 Solidity 未变。
- [ ] mutation：漏编码 recipient、放宽 head 检查、错 fee 区间、绕过 verifier 失败，必须使 conformance 或 model proof 失败；失败原因需对应目标义务。

**验收：** 报告为 LAND spec-proved + Solidity conformance-tested。Solidity implementation-proved 仍为 pending；仅凭 source hash 或 source map 不能把它升级。

## Task 6：组合定理和证明清单

**Files:** 创建 `Etna/Integration/Composition.lean`、`manifests/integration.json`、`scripts/check_coverage.py` 和 schema；扩展 `lander/src/statement.rs`、`crates/lander/tests/` 的配对真实合约测试。

**Interfaces:** `BatchSummary` 包含 parent/terminal checkpoint、head before/after、block count、statement fields；client 的合法 trace 定理产生该关系，landing 定理消费它。`compose_trace_landing` 显式接受真实 guest soundness，而不接受 Dummy 作为满足前提的实例。

- [ ] 证明 LAND-07，把 FI 消费总数、committee/certificate history、任意 cuts 和 landing 单调/支付关系接起来。
- [ ] 建立 machine-readable ledger：ID、theorem 名称/类型 digest、源符号/digest、前提、bridge 等级、测试。删除 ID、theorem 缺失、生成结果过期或降级时检查失败。
- [ ] 在真实合约配对测试中验证 Rust/Lean/Solidity 的 576-byte statement/摘要，以及 batch cuts 后最终 queue head 和费用区间一致。
- [ ] 对客户端固定 artifact revision 检查实际 contract source、ABI、layout、executable bytecode provenance；变更相关产物时运行两个 generator 两次，禁止手改 artifact。未变化的源可保持其原 provenance revision。

**验收：** 组合定理对任意有限有效 trace 成立；生产联动仍按 bridge 等级报告，guest soundness 未实现的事实不能从 ledger 消失。

## Task 7：接入 PR、nightly 和 release CI

**Files:** 创建 `.github/workflows/etna--formal.yml`、`formal/etna/scripts/{prepare_pair.py,run_conformance.py,check_provenance.py}`、报告 schema；仅在需要共享依赖时对既有 protocol/client workflow 加 additive job，不替换原测试。

- [ ] workflow 对 pull_request、push main、workflow_dispatch、nightly 触发；总会产生 `Etna formal gate`。内部 changes 检测覆盖 Lean/spec、protocol Etna/编译配置/公共依赖、client core/调用点/锁文件/生成产物、脚本及 workflow 自身，不能只监听 `.lean`。
- [ ] PR 开始解析并 checkout 两个 immutable head；分支合并后用同一 checkout。配对 runner 在临时目录按文件 ownership 合成 F/C/P/I；意外同路径不同内容冲突直接失败，不静默覆盖。
- [ ] 执行四个 job：`lean-proofs`、`rust-refinement`、`conformance`、`coverage`；汇总 job 使用 always，严格检查相关 jobs 的 result，fail/skip/cancel/timeout 均不通过。
- [ ] Lean 验证命令：在 `formal/etna` 运行 `lake build`，然后运行由完整 manifest 生成 imports 的 `lake env lean Audit.lean`。差分命令由 `python3 formal/etna/scripts/run_conformance.py --scope paired --seed 20261015` 统一驱动，内部调用 `lake env lean --run Check/<Domain>.lean`、生产 Rust test adapter 和 Foundry test adapter。
- [ ] 初始 timeout 配置：Lean 20 分钟、Rust/adapter 45 分钟、Docker 集成 60 分钟；这些是预算而非已测耗时。缓存可优化，不允许 timeout 后自动降为 advisory。
- [ ] 结束前重新检查 pair heads，并生成 source/tool/compiler/manifest/产物 digests 与每个 proof ID 的等级；head 前移则该配对结果失效，要求重新运行，不自动提交 pin。
- [ ] nightly 在相同全量定理之外执行更多 conformance seeds、较长 crash/switch traces 和 Task 3/4/5 的 mutants；保存 mutation 名称、目标义务和实际失败原因。
- [ ] 设置 branch ruleset required check 为稳定的汇总 job。release 流水线消费对应 release SHA/产物的报告；spec/conformance 绿色不能补足 implementation/guest/time-rule 的 pending。

**验收：** 用 proof 文件变化、仅生产 wrapper 变化、仅 fixture/toolchain/workflow 变化、无关 PR、Draft、两 PR 竞态前移六种演练验证触发和阻断。证明 statement/前提变更要求 proof reviewer 审核，不能靠更新 hash 自动批准。

## Task 8：Solidity 实现证明的独立门槛

**Files:** Task 1 inventory、`Etna/Refinement/Solidity/` 和 proof ledger；只有通过可行性验证后才引入固定版本的 EVM/Yul 语义依赖。

- [ ] 用实际 solc 设置产生的 runtime bytecode，确认 Solidity→IR/EVM 和代理 delegatecall 身份的完整映射。只证明不同编译设置下的 Yul 不能标记为现有部署产物已证明。
- [ ] 列出并实现实际所需的 Osaka opcode、external code checks、CALL/DELEGATECALL、BLOBHASH、SignalService、gas 耗尽及失败回滚语义；未经证明的 unsupported 返回 default 不可算覆盖。
- [ ] 证明具体执行语义 refinement 到 Task 5 操作模型，复用 LAND 定理。明确编译器、提取器、代理、外部 verifier/SignalService 的可信假设和覆盖范围。
- [ ] 完成前 ledger 保持 Solidity implementation-proved=pending；未获字节码 proof 时可以交付先前阶段，但发布文案不得宣称 `land()` 的生产实现已由 Lean 完整证明。

**验收：** 只有实际产物 refinement、axiom 审计和语义覆盖全通过，才能升级等级。工具适配工作量在 Task 1 inventory 后单独估算，不用本期协议证明的进度代替。

## 执行顺序与阶段验收

顺序：Task 1 → Task 2 → Tasks 3/4；Task 5 在共同类型固定后可独立推进；随后 Task 6 → Task 7。Task 8 独立于第一阶段交付，但其 pending 状态始终可见。

第一阶段完成标准：FI-01..09、COM-01..07、LAND-01..08 全部有 Lean 协议定理和审计；三个域的生产 conformance、mutation 和配对 gate 通过；Task 3/4 指定生产纯内核的 Rust refinement 全部完成。若提取被阻塞，可以先交付明确标为 spec-only 的中间里程碑，其 implementation-refinement 仍为 pending，不能宣称第一阶段或完整配对 gate 已完成。Solidity Task 8 单独验收。

本计划不要求先做全栈证明才允许评审实验性 PR。真实资金发布必须另行检查未完成的 implementation/guest/时间规则义务，不能仅以 `lake build` 成功放行。

## 本次交付的检查

只新增本设计与计划两份文档。已核对两 PR revision、生产关键调用点、编译配置和官方工具的版本/限制；本机 elan 未配置默认 toolchain。本轮未安装工具、未执行 Lean 证明、未运行协议/客户端测试、未修改工作流或运行时代码，也未提交或推送。
