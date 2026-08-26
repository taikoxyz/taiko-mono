# 结算窗口模型验证结果（settlement-window RESULTS）

> 由 `python3 settlement-window-model.py` 生成（规范草案 v1.46，附录 C）。
> 模型与性质定义见该文件头注释；每次修改 §5.2 全序 / §5.6 窗口状态机 / §7-§8 游标与 gas 规则后必须重跑并更新本文件。

```
RESULTS: settlement-window model — ALL PROPERTIES PASS
  [01] P1a 第5轮 A/B/C 环消解为 B>C>A
  [02] P1b 随机候选: 反自反/完全/传递
  [03] P2 收盘赢家与提交顺序无关 (全部 24 种排列同一赢家)
  [04] P3a provisional 接受不改 canonical
  [05] P3b 更重候选可对同一冻结基线验证并取代
  [06] P3c 取代仍不改 canonical
  [07] P3d 收盘恰好提交赢家一次
  [08] P3e 游标单调且无重复消费(单次提交,消费=赢家终局-基线)
  [09] P4 lane 洗白抵抗: 13 块仅强制首链 < 3 块内容链
  [10] P5 lazy close 不改赢家与 canonical
  [11] P5b 收盘后候选只能开启下一窗口(赢家仍是窗口内最重)
  [12] P6a 纯函数: 同一 L1 历史重放同一状态
  [13] P6b 重组截断后重放: 被重组掉的候选原子消失,状态一致
  [14] P7 共享 gas 预算下 300 组随机可达状态(含非创世游标)均存在合法块;前缀守双上限
  [15] P8 桥接满载洪泛下普通队列每块仍消费 ≥ 保证容量(不被饿死)
  [16] P9a 设置器不变量互检: Δ_lag,final ≥ prov+W_settle_max; D_anchor_max ≥ 最坏路径; W_settle ≥ 证明+纳入
  [17] P9b 因果序 anchor.L1_time ≤ L2_time(slot): 旧 slot 配新 anchor 被拒;等号允许;正常组合被收
  [18] P10 罚没后落地的候选拒含该 signer;生效前已落地祖父化
  [19] P11 兜底资格快照保持到窗口收盘,provisional lag 重置不撤销
  [20] P12a 中途入队: 先前候选终局不变,更重候选对同一冻结游标基线可消费新条目,canonical 不动
  [21] P12b append-only ⇒ 位置稳定: 条目入队时点不影响验证结果(同赢家同终局)
```

覆盖对照（独立审核第 5 轮要求 + 实现前复核 + DeepSeek 批次 → 性质）:

- 严重 1（全序非传递环）→ P1a/P1b/P2
- 严重 2（provisional 推进 canonical 游标）→ P3a–P3e
- 第 3 轮发现 3（lane 洗白）→ P4
- lazy close 与收盘边界 → P5/P5b
- L1 重组/纯函数 → P6a/P6b
- 第 4/5 轮 gas 死锁与双约束前缀 → P7
- r19-1 桥接预留（`C_bridge`）饿死抵抗（DeepSeek-on-v1.43 C2）→ P8
- §8/§12 设置器不变量在**独立声明的部署值**间互检（r46 非空化，DeepSeek-on-v1.45 W1——非空化当即抓出 `Δ_lag,final` 8-epoch 初值与自身公式的矛盾，重校为 9 epoch）与因果序显式时基（含等号边界，建议 3）→ P9a/P9b
- §4.3 罚没生效以候选 L1 落地时点祖父化 → P10
- §6.3 兜底资格在窗口开启时快照、保持到收盘（含 lag_prov/lag_final 拆分，`Δ_lag,final` 阈值）→ P11
- §5.6 基线冻结 = 游标/状态、队列 append-only 按序号引用（窗口中途入队确定且不改先前候选终局，DeepSeek-on-v1.45 W2）→ P12a/P12b

**尚未覆盖（实现前复核清单其余部分，见 `settlement-window-implementation-review.md`）**：签名/证明/执行合法性为占位布尔（模型只精确建模共识新增对象：全序 key、窗口状态机、游标算术、gas 份额、时序几何）；Solidity 级 `acceptCandidate` 入口的 gas 成本与存储布局的分析性（非可执行）复核见实现前复核文档；最终判定 = 所有者 + 人类安全评审。
