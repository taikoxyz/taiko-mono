# Etna Lean 4 Verification Design

本设计针对 FI、委员会切换和 `EtnaInbox.land()` 建立 Lean 4 证明与持续检查。第一阶段交付协议模型的机器检查证明、生产实现的对应关系检查和配对 CI；Rust 提取后的实现证明单独验收，Solidity 字节码证明也单独验收。三种结果不得统一标记成“生产代码已形式化验证”。本设计供评审，本轮不实施运行时代码或工作流。

## 1. 源码基线与范围

| 部分                                                          | 固定 revision                              | 主要源码                                                                                                                       |
| ------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| [PR 22286](https://github.com/taikoxyz/taiko-mono/pull/22286) | `41241d5e6440c2ab244ccfdf572d1af8016f70c6` | `EtnaInbox.sol`、`LibEtnaForcedInclusion.sol`、`IEtnaInbox.sol`                                                                |
| [PR 22280](https://github.com/taikoxyz/taiko-mono/pull/22280) | `2d00eb054d767093742af6af6a061d30a3d2d118` | `abci::forced`、`engine::forced`、`schedule`、`app::{validate,process,finalize}`、`lander::{history,batch,validate,statement}` |

第一阶段不扩展到 staking registry 的全量选举/排序证明、journal、整个 CometBFT、MPT/Keccak/Ed25519 的内部算法、EVM 执行器或真实 ZK guest。委员会选择函数在本阶段作为对完整认证快照的确定性函数，验证快照选择和切换使用正确，不声称已证明完整 top-n 实现。

保持 envelope v5、payload v4、journal schema 8、APP_VERSION 2、V6 十八词 statement、六字段 LandInput、storage layout 和生产协议行为。当前 Solidity 编译配置是 solc 0.8.30、optimizer runs 200、EVM Osaka；不为适配证明工具切换 via-IR 或删改生产 opcode。

## 2. 证明层次与工具选择

| 层次                   | 工具与输出                                                            | 可以宣称的保证                                                                             |
| ---------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 协议规格               | Lean 4、Mathlib、Lake；归纳证明和位宽引理                             | 在显式前提下，对所有合法参数和任意有限有效执行序列成立；不依赖测试枚举范围                 |
| Rust 纯内核            | Charon + Aeneas Lean backend；生成函数到规格函数的 refinement theorem | 仅对成功提取、无未证明外部 stub 的生产函数成立，提取器/编译器和未覆盖适配层属于可信边界    |
| Rust/Solidity 对应检查 | Lean 可执行规格 + Rust/Foundry adapter + JSONL 差分/trace 测试        | 有限样本和 trace 上实现符合规格，具有回归价值，但不是实现 refinement proof                 |
| Solidity 实现          | 对实际编译产物的 Lean EVM/Yul 语义 refinement，另设可行性验收         | 只有完成实际产物覆盖后才标记 implementation-proved；本阶段先交付规格证明和真实合约对应检查 |

推荐先做上述分层方案。仅手写 Lean 模型的方案成本低但无法防止实现漂移；直接对完整 Rust/Osaka 字节码做端到端证明，前置工具适配成本尚未确认。

第一版验证环境锁定：

- Lean：`leanprover/lean4:v4.35.0-rc4`，与下面的 Aeneas backend 声明一致。
- Aeneas：`673f9e30e1e2a81b355df9a9550168e672a10d4e`。
- Mathlib：`1f414401f69059aa7eead47b53ee40bd38455eeb`，其余传递依赖锁定到 `lake-manifest.json`。
- Charon：`a5276d59516b6e7dc519441e244399ab8d429107`，来自该 Aeneas revision 的 `charon-pin`；extractor Rust：`nightly-2026-09-17`，来自该 Charon 的 `rust-toolchain`。全部提交到 `tools.lock.json`，不得使用浮动 main/nightly。生产正常构建仍使用仓库的 Rust 1.95。
- Rust 提取 smoke test 必须先通过。若配套工具不兼容，则 Rust refinement 状态保持 pending；不能以手抄 Lean 函数替代生成结果。工具升级必须作为独立受检变更。

Lean 最新稳定版当前是 4.35.0，但此处先遵循 Aeneas 的 rc4 兼容组合。Clear 当前 toolchain 为 4.9.1，EVMYulLean 为 4.22.0；不将三套不兼容 `.olean` 混用。公开 Yul 模型对 gas、外部 code 操作等仍有限制，因此本设计不假设它能直接验证当前 `land()`。

## 3. 共同数据模型和可信边界

在 `formal/etna` 建立单一 Lean package：

```text
Etna/Common/Words.lean          位宽、checked arithmetic、状态/错误类型
Etna/Common/Assumptions.lean    外部认证和执行事实的显式接口
Etna/FI/{Model,Proofs}.lean
Etna/Committee/{Schedule,Transition,Proofs}.lean
Etna/Landing/{Statement,Model,Proofs}.lean
Etna/Integration/Composition.lean
Etna/Refinement/Rust/           机器生成的 Rust 翻译及人工 refinement 证明
Check/{FI,Committee,Landing}.lean
manifests/{core,client,contracts,integration}.json
scripts/                       配对 checkout、生成、审计、差分、覆盖报告
```

数学计数使用 Nat，边界层使用 `Fin (2^48)`、`Fin (2^64)` 和 `Fin (2^256)` 或带范围证明的等价类型。每次从数学计数返回机器整数都需要范围引理；错误、阻塞和成功是不同构造子。不能用 Nat 模型掩盖实际 checked/wrapping/saturating 行为。

所有关键定理用 theorem 参数显式接受以下外部前提，而不新增全局 `axiom`：

1. 认证事实：MPT 返回的是指定 Inbox、slot 集合和指定 anchor root 下的内容；完整 registry snapshot 对应指定 parent anchor。
2. 编码事实：canonical EIP-2718 判定和 preimage/hash 检查结果与实际字节一致。解析器、hash 内部实现本期未证明。
3. 执行事实：canonical skip 的 completed singleton 结果对应同一认证 parent、同一 candidate attributes 和精确单交易输入；空结果确实来自已完成执行。RPC 失败不提供这种事实。
4. 共识事实：CometBFT 在高度 h 返回的 validator updates 于 h+2 生效，已提交历史有效。密码学验签结果使用与 CometBFT 一致的 ZIP215 规则。
5. 交易事实：EVM 顶层 revert 恢复该交易产生的 storage、外部调用效果和日志；成功外部调用必须满足其 frame condition；不存在本交易内获授权的恶意升级绕过接口状态。
6. 证明事实：真实 verifier 接受意味着 guest 验证了声明的批次关系。当前 DummyProofProvider 不满足这个前提，因而不能得到生产落链有效性结论。

CI 审计定理的完整类型和传递 axiom 依赖。允许 Lean 标准的 `propext`、`Classical.choice`、`Quot.sound`，拒绝 `sorryAx`、自定义 axiom 和 `native_decide` 引入的额外信任。定理显式前提也需要人工 review：axiom 审计本身不能发现“把待证明目标作为前提”的空洞定理。

## 4. FI 的证明契约

模型分成 `classify`、`resolve`、`advance` 三步。分类允许输出 NeedsSkip；只有 resolve 取得合格的 completed singleton 证据后，NeedsSkip 才能转为消费。全局 commit 从 resolved 结果更新 cursor。

| ID                              | 定理和精确性质                                                                                                                                                                                  |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FI-01 `due_exact`               | 对合法 timestamp/delay/anchor，due 恰为 `anchorTs >= entryTs + delay` 的宽位算术；u64 加法溢出不会使条目提前到期。证明 u128 加法可容纳两个 u64。                                                |
| FI-02 `authentication_required` | 存在 pending entry 时，缺 proof、错 index、错 Inbox/root/slots、超长或错误非空 preimage 不能产生 accepted consumption。认证内部正确性是显式前提。                                               |
| FI-03 `included_iff_first`      | 在认证前提下，canonical、长度不超过 8192、hash 匹配的交易位于执行列表位置零时消费一项，包括 pre-due 和 EVM revert；后续位置和替代交易不能因此消费。                                             |
| FI-04 `predue_no_skip`          | 未 due 且没有合法位置零包含时，cursor 保持；无效交易字节不能提前 skip。                                                                                                                         |
| FI-05 `due_requires_resolution` | pending 且 due 的 accepted block 必须 include 或合法 skip；NeedsSkip 自身不构成消费授权；空 preimage 只有确实匹配空 admission hash 才能证明其字节。                                             |
| FI-06 `skip_fail_closed`        | canonical skip 的 error、timeout、cancel、missing history、错误 parent/attributes、malformed result、retained transaction 均不能产生 consumed index。                                           |
| FI-07 `cursor_step_and_trace`   | 单块 cursor' ∈ {cursor,cursor+1}；推进的 index 等于 parent cursor 且小于其认证 tail；任意有效 block list 的总增量等于合法消费数，且不超过块数。                                                 |
| FI-08 `hot_cold_equivalent`     | 对相同 canonical envelope、committed context 和确定性认证执行事实，hot/cold 的消费结果、commit 后 cursor 和重启状态相同；上下文改变不能复用旧 verdict。该定理不保证网络可用或 replay 完成时间。 |
| FI-09 `no_age_only_consumption` | 不存在仅因条目太老而消费/删除的规则；无 expiry 分支。                                                                                                                                           |

生产对应路径：`abci/src/forced.rs` → `engine/forced.rs` → `app/process.rs` / `app/finalize.rs`，以及 lander 的相同检查。对 async adapter 的差分检查与纯内核 refinement 分别报告。

## 5. 委员会切换的证明契约

定义 `L >= 3`，`H(t)=1+t*L`。仅对 `t >= 1` 定义 `D(t)=H(t)-3`、`S(t)=H(t)-2`；epoch 0 使用 genesis committee 和显式 cutoff。对无法用 u64 表示的高度保留实际 checked failure/panic 分类，不把域外值当有效高度。

| ID                                 | 定理和精确性质                                                                                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| COM-01 `schedule_exact`            | D=S−1、S+2=H；仅 S(t) 产生目标 t 的更新，其他高度不产生；证明有效域内算术和 epoch 边界。                                                                                                   |
| COM-02 `parent_anchor_unique`      | incoming committee 的 snapshot root 和资格 cutoff 来自 D(t) 的 committed parent anchor；候选块更新后的 anchor 不能替换它。非 switch 的额外 committee witness 拒绝。                        |
| COM-03 `activation_exact`          | outgoing 集合在 H(t) 前继续生效，incoming 在 H(t) 生效；需要的 outgoing/current/pending 记录存在且一致，冲突/空结果不能静默回退。                                                          |
| COM-04 `certificate_authority`     | 接受证书只能计入正确高度、chain、block identity 下的 distinct valid block precommit；nil/absent 不计 power；严格 `3*signedPower > 2*totalPower`，等于 2/3 不通过。密码学验签内部作为前提。 |
| COM-05 `batch_cut_equivalent`      | 从同一个认证 checkpoint 对同一有效历史进行任意连续切分，组合 replay 的结果等于一次 replay；跨 D/S/S+1/H 切分仍保持 active/pending set 和最终 cursor 相同。                                 |
| COM-06 `replay_deterministic`      | 同一 genesis、有效历史和外部认证事实下，在线提交和 crash/replay 重构得到同一委员会状态与更新列表。                                                                                         |
| COM-07 `backpressure_switch_bound` | 当 U=d_max−margin_v、L>=U+3 且在 S(t) 接受块满足 S(t)−checkpoint<=U，则 checkpoint>H(t−1)。同时证明参数溢出/非法差值拒绝。                                                                 |

不以此重新证明动态验证者集合的完整 BFT 安全性；每个 active set 的 Byzantine power、incoming 可用性、stake/key retention 均是另外的系统假设。

## 6. land() 的证明契约

模型按生产顺序执行：检查 → 构建 statement → tentative consume/checkpoint/signal/log → verifier → fee payment。先定义可能失败的步骤，再证明顶层 transaction wrapper 的回滚；不能通过在模型里先验规定“失败不改状态”来替代逐步骤对应检查。

| ID                                | 定理和精确性质                                                                                                                                                                                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| LAND-01 `bounds_preserved`        | 成功必须严格推进 checkpoint，batch 长度不超过 maxBatchBlocks，lastHeight 可表示为 uint48；headBefore<=headAfter<=tail 且 head 增量不超过块数。                                                                                                               |
| LAND-02 `fees_exact_once`         | 支付的 gwei 总额等于区间 [headBefore,headAfter) 存储费用之和；队列 head 单调，后续调用不能再次消费同一区间。证明求和和换算不溢出 uint256。                                                                                                                   |
| LAND-03 `recipient_bound`         | recipient 非零，十八词编码包含其地址；复制相同 calldata 的调用者不能改收款方。证明 transfer 指令/事件的目标和金额，不把任意 callback 后的最终余额增量等同于费用。                                                                                            |
| LAND-04 `rollback_atomic`         | verifier、SignalService 或 payment 失败，顶层交易恢复 Inbox、队列 head、checkpoint、外部 checkpoint 效果和日志；回调不能重入 land/save 消费第二次。依赖显式 EVM rollback/frame 语义。                                                                        |
| LAND-05 `statement_complete`      | domain、两链 ID、Inbox/registry 身份、generation、parent checkpoint、config、末块/root、L1 reference、ordered blob commitment、head before/after 和 recipient 按既定顺序组成十八个 ABI word。编码对这十八个字段可逆；hash 不可重绑定另依赖抗碰撞前提。       |
| LAND-06 `rust_solidity_encoding`  | 相同字段输入得到相同 576-byte preimage。Lean 证明编码结构；Rust/真实合约运行差分验证字节和 digest。后者本阶段不是 Solidity 字节码证明。                                                                                                                      |
| LAND-07 `composition_consumption` | 当真实 guest 证明每块 FI 和委员会关系时，按任意合法 batch cuts 的 land head 增量等于区间内合法消费数，费用不漏付/重复付。Dummy 模式不能满足 guest soundness 前提。                                                                                           |
| LAND-08 `reference_and_blobs`     | L1 reference 必须在当前块之前且 age<=8191；age<=256 使用 blockhash，其余使用成功且恰好 32-byte 的 EIP-2935 响应，并要求非零 hash。blob 列表取当前交易 BLOBHASH 的有序非零前缀，必须非空，不能接受调用者替换的列表。历史接口/交易环境内容的正确性是显式前提。 |

## 7. 两个 PR 的边界和集成方式

共享底座先作为独立的小型基础变更 F 合入，让两条分支具备相同的 Lean types、工具锁定和 scripts，不在两个 PR 维护各自的公共模型。无需把整个 client PR 合进 protocol PR。最终组合检查由集成变更 I 维护，F/I 是计划中的共享提交组，不在本轮创建 PR。

- **22280**：拥有 `Etna/FI`、`Etna/Committee`、Rust refinement、client trace adapter 和相应 manifests；在生产 crate 提取小型、无 I/O、无 Alloy/CometBFT/Tokio 依赖的 `etna-consensus-core`。ABCI 和 lander 都调用它，原有认证/执行适配层保留。新 core 是提取目标，不另写仅用于证明的 Rust 算法副本。
- **22286**：拥有 `Etna/Landing`、真实合约 conformance adapter、statement/fee/rollback 对应检查和相应 manifests。优先增加 harness/tests，不改合约 ABI、layout、编译路径或执行语义。字节码证明所需的语义扩展另行列为未完成义务。
- **F/I**：拥有共同工具、`Etna/Integration` 和 `.github/workflows/etna--formal.yml`。既有 protocol/client CI 保持，新增稳定名称的汇总 gate。

配对 CI 在运行开始解析两边的 immutable head，记录实际 checkout 和源文件 digest；结束时重新检查，任何一边移动则要求重跑。不要把“自己的新 commit SHA”写进自己的 manifest，也不要让两个 PR 相互提交 head pin 而产生循环更新。客户端既有生成产物 pin 由 contract-source/ABI/layout/bytecode provenance 检查，相关内容改变才按现有脚本再生成。

## 8. CI 和发布门槛

`Etna formal gate` 在每个 PR 上总会产生状态，包含 Draft；使用 read-only token，在普通隔离 runner 执行。workflow 路径不使用全局 path filter，由内部 changes job 判断范围。无关 PR 明确报告 not-applicable；相关 PR 的证明/生成/对应检查任一 skipped、cancelled、timeout 或失败都使 gate 失败。不能把 skipped 当形式化成功。

PR 检查包含：

1. **lean-proofs**：全部相关 theorem 编译、显式前提清单及 transitive axiom 审计；缓存键含 Lean/dependency/tool/source digests。
2. **rust-refinement**：从当前生产 core 重新生成 LLBC/Lean 并证明一致；阻止 generated file 漂移、missing theorem 和未经证明的 stub。只对提取实际覆盖的函数给出 implementation-proved。
3. **conformance**：Lean vs production Rust vs Foundry 的字段/trace 比较；覆盖 FI 失败类、委员会边界、V6 编码、费用和 rollback。
4. **coverage**：每个 ID 指向 theorem、生产函数、桥接等级、测试和假设；不得缺 theorem、偷偷删 ID、降低 bridge 等级或改变前提而不经过 review。

nightly 跑更广的随机 trace、真实 Docker replay 和 mutation。Lean 归纳定理仍每个 PR 全量检查，nightly 扩大的是实现测试样本，不是把定理缩小为有限枚举。

CD/release 读取同一发布源码与产物的报告，不接受旧 SHA 的证明结果。报告分别列出 spec-proved、Rust implementation-proved、Solidity implementation-proved 和 conformance-tested。真实资金发布还要求真实 guest/verifier 及其 statement relation 验证完成；本期不能把 Dummy、未证明的 Solidity 对应关系或未决时间规则标成绿色证明。

本期只证明安全性质和明确前提下的状态一致性。不承诺 wall-clock FI deadline；PBTS/local clock、L1 finality、在线 quorum、队列积压和 settlement 活性需另定机制和前提。可以保留时间停滞反例作为设计回归，但不能把它当作上线活性证明。

## 9. 工具依据

- [Lean axiom 和 native evaluation 信任边界](https://lean-lang.org/doc/reference/latest/Axioms)
- [Aeneas 的 safe Rust 子集、生成方式和 Lean backend](https://github.com/AeneasVerif/aeneas/tree/673f9e30e1e2a81b355df9a9550168e672a10d4e)
- [Aeneas backend toolchain](https://github.com/AeneasVerif/aeneas/blob/673f9e30e1e2a81b355df9a9550168e672a10d4e/backends/lean/lean-toolchain)
- [Aeneas Charon pin](https://github.com/AeneasVerif/aeneas/blob/673f9e30e1e2a81b355df9a9550168e672a10d4e/charon-pin) 和 [Charon Rust toolchain](https://github.com/AeneasVerif/charon/blob/a5276d59516b6e7dc519441e244399ab8d429107/rust-toolchain)
- [Clear 的 Yul verification framework](https://github.com/NethermindEth/Clear/tree/6ef2e7eda01080e5d5fd7474354c1a71adab5071)
- [EVMYulLean 的模型及已声明限制](https://github.com/NethermindEth/EVMYulLean/tree/047f63070309f436b66c61e276ab3b6d1169265a)
