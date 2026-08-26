# 结算窗口实现前复核（settlement-window implementation review）

> **§12 第 18 项"实现前的门"的后半交付（r44）。非规范性分析文档**：规范以
> [`slot-chain-spec.md`](slot-chain-spec.md) 为准,可执行语义以
> [`settlement-window-model.py`](settlement-window-model.py) 为准。本文回答两个问题:
> (1) 模型此前未覆盖的项是否已闭合;(2) §5.6 窗口状态机落到 Solidity（Inbox 入口）时的
> 存储布局与 gas 成本是否可接受、与现有 Inbox 架构如何对接。
> **本门不自动放行**:最终判定 = 所有者 + 人类安全评审;文末列出仍开放项。

## 1. 模型未覆盖项的闭合（r43 边界 → r44）

r43 交付时如实标注了四个模型外项,r44 全部入模型,r46 又加 P12 与 P9a 非空化（21 项断言全过,见
[`settlement-window-RESULTS.md`](settlement-window-RESULTS.md)）:

| r43 未覆盖项 | r44 处置 | 性质 |
| --- | --- | --- |
| 桥接预留（r19-1 `C_bridge`） | 模型曾把 `C_force` 全额给桥接队列（DeepSeek-on-v1.43 C2,模型自身的 bug）;修为桥接前缀先按 `C_bridge` 封顶、普通队列拿余量 | P8:桥接满载洪泛下普通队列每块仍消费 ≥ 保证容量 |
| anchor 新鲜度/因果序 | 时序几何入模型：设置器不变量在独立声明的部署值间互检（r46 非空化，当即抓出 Δ_lag,final 8-epoch 初值与自身公式的矛盾并重校为 9 epoch）；因果序按显式时基检验（含等号边界） | P9a/P9b |
| 罚没生效 | §4.3 r41 规则入模型:判据是**候选的 L1 落地时点**（L1 自己的记账,不可伪造）——生效后落地拒含该 signer,生效前已落地祖父化 | P10 |
| 兜底会计快照 | §6.3 r42/r44 规则入模型:资格按 `lag_final > Δ_lag,final` 开窗即快照、保持到窗口收盘;恶意同伙落短候选清零 `lag_prov` 不撤销资格 | P11 |

模型仍然**只**精确建模本设计新增的共识对象（全序 key、窗口状态机、游标算术、gas 份额、
时序几何）;签名/证明/执行合法性是占位布尔——它们由现有证明系统承担,不是本设计新增面。

## 2. Solidity 级 `acceptCandidate`：存储布局

关键结构性事实:**窗口是严格串行的**（一条 L2 链同一时刻至多一个开启中的窗口,收盘才开
下一个）→ 窗口状态用**固定槽位复用**,无 per-window mapping、无无界增长;且**只存当前最优**
（best-only）——被取代的候选不留任何状态（它们的数据在 calldata/blob 与事件里,合约状态
只记赢家账）。

建议布局（遵循 protocol 惯例:结构体存哈希不存全量、字段紧凑打包）:

```solidity
struct WindowState {
    // -- 冻结基线 (openWindow 一次写入) --
    bytes32 baseCommit;    // = keccak(F.tipHash, F.stateRoot, F_consumed, m_consumed)
                           //   候选证明的公共输入必须等于它 (基线冻结 §5.6)
                           //   注意: 冻结的是游标, 不是队列内容快照 (r46, §5.6 澄清)——
                           //   队列承诺须逐条/append-only (哈希链或 MMR), 证明按序号引用
                           //   条目; 不得把"落地时刻的单一可变队列根"做公共输入, 否则
                           //   窗口内先后候选的公共输入漂移 (模型 P12)
    // -- 窗口与最优候选 (打包进两个词) --
    uint48  closeAtL1Block; // 收盘高度; 0 = 无开启窗口
    uint8   bestLane;       // 1 bit 即够
    uint32  bestCount;      // 块数
    uint48  bestTipSlot;    //
    // (以上四段可打包为一个 uint128 序标量, 见 §3 gas)
    bytes32 bestTipHash;    // 平手仲裁 + 下一基线的 tip
    bytes32 bestEndCommit;  // = keccak(tip, stateRoot', F_consumed', m_consumed')
                            //   收盘时展开提交 (随收盘交易 calldata 提供原像并校验)
}
```

≈ **4 个存储词**（`baseCommit` 1 + 打包序标量 1 + `bestTipHash` 1 + `bestEndCommit` 1）,
加 canonical 侧既有的落地头/游标词。对比:v15 线的证书状态机是 per-episode 动态状态;
这里是**固定 4 词复用**,升级安全(storage gap)与 ring-buffer 化都容易。

全序 key 的紧凑性是 r42 四元组设计的直接红利:`(lane, count, tip_slot)` 打包成一个
`uint128` 标量后,"严格更重"= **一次整数比较**;`tip_hash` 只在前三段全等时才参与仲裁
（按 §5.2,同 lane 同块数同 tip slot 的两个不同链哈希必然不同,比较哈希大小即可,无歧义）。

## 3. Solidity 级 `acceptCandidate`：gas 分析

候选提交 = 原子落地交易（§6.1:数据 + 有效性证明一笔）,即**现有 propose+prove 合并路径**。
`acceptCandidate` 新增的边际成本（相对现有 Inbox 的 prove 入口）:

| 步骤 | 操作 | 量级 |
| --- | --- | --- |
| 基线核对 | 1 SLOAD (`baseCommit`) + 与证明公共输入比较 | ~2.1k |
| 开窗（仅首候选） | 写 `closeAtL1Block`（打包词首写） | ~22k（每窗口一次） |
| 序比较 | 1 SLOAD（打包序标量）+ 一次 `uint128` 比较（罕见平手再比 `bestTipHash`,+1 SLOAD） | ~2.2k |
| 取代/记账 | 写打包序标量 + `bestTipHash` + `bestEndCommit`（非零→非零 3×SSTORE） | ~15k（首写 ~66k） |
| 事件 | 1 LOG（候选被接受/取代） | ~2k |

**边际 ≈ 20–25k gas/候选**,相对证明验证本身（数百 k 级）是低一个量级的加项;**常态窗口只有
一个候选**（§5.6:无竞争时无人多花一分钱）,常态边际就是"开窗 + 首写"一次。`closeWindow`
（或并入下一候选交易的 lazy close,语义 = 收盘先于接受,r44 W2）:校验 `bestEndCommit` 原像
→ 展开写 canonical（落地头 tip/stateRoot 承诺 + `F_consumed`/`m_consumed` 游标,游标可共词
打包,≈ 2–3 SSTORE）→ 清零窗口词（退款友好）→ ≈ **25–35k gas**。整体结论:**结算窗口不改变
落地成本的数量级**,主导项仍是证明验证与数据发布——这正是 option C"比较只在已落地已证明候选
间进行"的结构性红利,入口只做 O(1) 标量比较。

Griefing 面:刷候选者每次都要付全额证明费 + 上述边际 gas,且必须**严格更重**才被接受
（否则 revert,合约状态零变化）——无状态膨胀攻击面;"接受后被更重者取代"只覆写同三个词,
不留垃圾。

## 4. 与现有 Inbox 架构的对接路径

现行 Shasta `Inbox.sol`（`contracts/layer1/impl/Inbox.sol`）是 propose → prove → finalize
三段;本设计的映射:

- **propose+prove 合并**为候选提交（原子落地,§6.1）→ 走 `acceptCandidate`;
- **finalize** → `closeWindow`（确定性高度触发,任何人可调,或 lazy 并入下一候选/下一窗口
  首交易——与现行"finalize 可由后续交易捎带"的做法同型）;
- 现有的 ring buffer/哈希承诺惯例直接适用（§2 布局就是按它写的）;
- **L1 重组**:窗口态是 L1 历史纯函数（P6),无跨交易证书状态机——回滚语义显著简单于 v15
  （§12 第 9 项仍须把"落地头 + 状态根 + 游标 + lag 快照"写成原子回滚清单）;
- **强制包含队列**:`saveForcedInclusion` 入队侧不变;消费侧改读"窗口基线 → 收盘提交"
  （§7 r42）,游标推进只发生在 `closeWindow` 的唯一一笔原子提交里（P3e:单调、无重复消费）。

未验证声明的如实标注:上述 gas 数字是**分析值**（按 EIP-2929 冷/暖与 SSTORE 定价手算）,
实现时须以 `forge snapshot` 实测为准（repo 既有 `pnpm snapshot:l1` 流程）;与现行 Inbox 的
具体函数签名对齐属实现工作,不在本文档范围。

## 5. §12 第 18 项原清单 (a)/(b)/(c) 逐项处置

| 项 | 内容 | 状态 |
| --- | --- | --- |
| (a) 伪代码/状态机 | 块合法性/父块选择/全序/窗口状态机/落地/强制包含/共享 gas | **已交付**:§5.6 伪代码 + 附录 C 可执行模型（P1–P11）覆盖全序、窗口、游标、gas、时序;**残余**:§6.4 恢复流程与 §12 第 9 项 L1 回滚清单仍是散文,实现时须一并伪代码化 |
| (b) lookahead 确定性加权抽样算子 | 种子源、抽样函数、权重上限的确切算子 | **仍开放**——不阻塞结算窗口子系统,但阻塞排班电路实现,动手实现排班前必须闭合 |
| (c) 术语区分 | L2 接受最终性 vs L1 最终性 | **已完成**:r41/r42 起词汇固定为 provisional / window-final / L1-final(`F_l1`) 三级,附录 B 收录 |

## 6. 仍开放项（诚实清单——本门放行的边界）

1. (b) lookahead 抽样算子精确定义（上表）。
2. §12 阻塞级待定项 8（证明系统中断豁免）与 12（强制条目 nonce 抢占防护）——与窗口正交,
   但实现主网前必须闭合。
3. gas 分析值 → `forge snapshot` 实测;`W_settle`/`Δ_lag,final`/`D_anchor_max` 等参数标定。
4. §6.4 恢复流程与 L1 回滚清单的伪代码化（(a) 残余）。
5. **人类安全评审 + 所有者签字**——模型与本复核是机器可检的门,不替代人的最终判定。
