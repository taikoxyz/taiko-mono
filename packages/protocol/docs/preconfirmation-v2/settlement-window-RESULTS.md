# 结算窗口模型验证结果（settlement-window RESULTS）

> 由 `python3 settlement-window-model.py` 生成（规范草案 v1.43,附录 C）。
> 模型与性质定义见该文件头注释;每次修改 §5.2 全序 / §5.6 窗口状态机 / §7-§8 游标与 gas 规则后必须重跑并更新本文件。

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
  [14] P7 共享 gas 预算下 300 组随机可达状态均存在合法块;前缀守双上限
```

覆盖对照（独立审核第 5 轮要求 → 性质）:

- 严重 1（全序非传递环）→ P1a/P1b/P2
- 严重 2（provisional 推进 canonical 游标）→ P3a–P3e
- 第 3 轮发现 3（lane 洗白）→ P4
- lazy close 与收盘边界 → P5/P5b
- L1 重组/纯函数 → P6a/P6b
- 第 4/5 轮 gas 死锁与双约束前缀 → P7

**尚未覆盖（实现前复核清单,§12 第 18 项后半）**：签名/证明/执行合法性为占位布尔（模型只精确建模共识新增对象:全序 key、窗口状态机、游标算术、gas 份额）;anchor 新鲜度/因果序、罚没生效、兜底会计快照未入模型;Solidity 级 acceptCandidate 入口的 gas 成本与存储布局。
