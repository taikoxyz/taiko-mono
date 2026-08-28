#!/usr/bin/env python3
"""排班表 lookahead(slot) 的可执行参考实现 + 性质测试（§3.2 的代码化，r47）。

§3.2 正文嵌有与本文件一致的核心代码；本文件额外带性质断言，直接运行:
    python3 lookahead-model.py
零依赖。抽样算子（capped 权重前缀和 + 种子模总权重定位）是 §12 第 18 项 (b)
的具体定形候选，待所有者确认后该待定项闭合。
"""

import hashlib

# ---------------------------------------------------------------------------
# 参数（§3.2 / 参数总表）
# ---------------------------------------------------------------------------
L1_PER_L2 = 12            # 1 个 L1 slot(12s) = 12 个 L2 slot(1s)
W_SIZE = 384              # 排班窗口 = 384 个 L2 slot（一个 epoch；固定对齐分区）
H_LOOK = 768              # 前瞻视界：任一时刻至少未来 H_LOOK 个 slot 排班已定
L1_EPOCH = 32             # 每 L1 epoch 的 L1 slot 数
F_FINAL_L1 = 2 * L1_EPOCH # L1 最终性距离（≈2 epoch）
D_SNAP_L1 = 5 * L1_EPOCH  # 快照延迟；设置器不变量 D_snap ≥ H_look/12 + F_final + 余量
W_MAX = 0.20              # 单地址有效权重上限（运维卫生，防不了女巫，§3.2 诚实定性）
GENESIS_L1 = 10_000       # 创世时 L2 slot 0 对应的 L1 slot（示例值）


def h(*xs) -> int:
    """确定性哈希 → 大整数（实现中为 keccak；这里 sha256 足以演示语义）。"""
    m = hashlib.sha256()
    for x in xs:
        m.update(str(x).encode())
        m.update(b"|")
    return int.from_bytes(m.digest(), "big")


# ---------------------------------------------------------------------------
# 核心计算（与 §3.2 嵌入代码一致）
# ---------------------------------------------------------------------------
def window_of(slot: int) -> int:
    # 固定对齐分区：W(slot) = floor(slot / W_size)。
    # 不是滑动视界——同一 slot 在所有时刻、对所有观察者映射到同一窗口 。
    return slot // W_SIZE


def l1_slot_of(l2_slot: int) -> int:
    # 创世映射：L2 slot(1s) 所在的 L1 slot(12s)。
    return GENESIS_L1 + l2_slot // L1_PER_L2


def snapshot_height(w: int) -> int:
    # 唯一快照高度：窗口起点对应的 L1 slot 减 D_snap。
    # D_snap ≥ H_look/12 + F_final + 余量 ⇒ 排班被使用前快照已 L1 最终化，
    # 种子与注册表都不受 L1 重组影响 。
    return l1_slot_of(w * W_SIZE) - D_SNAP_L1


def seed(w: int, l1_randao) -> int:
    # 种子：快照高度所在 L1 epoch 的 RANDAO（EIP-4788 信标根电路内可证）。
    # 种子按窗口取一次、不按 slot 取——窗口内所有 slot 共享同一熵源 。
    return h("seed", l1_randao(snapshot_height(w)))


def effective_weights(registry: dict) -> dict:
    # 有效权重 = min(保证金, w_max × 保证金总和)。单次封顶、不迭代重归一
    # ——超额部分作废而不重分配，算子保持一遍线性扫描、电路友好。
    total = sum(registry.values())
    return {a: min(b, W_MAX * total) for a, b in registry.items()}


def weighted_pick(registry: dict, r: int) -> str:
    # 确定性加权抽样（§12-18(b) 的定形候选算子）：
    #   1. 地址按【注册序号】固定排序（快照内在序，与字典序无关，防 grinding 注册名）;
    #   2. 计算 capped 权重的前缀和（定点整数：权重以 wei 计，无浮点）;
    #   3. x = r mod 总权重，x 落进哪个前缀区间就选谁。
    # 被选概率 = 有效权重占比；电路内为一遍前缀和 + 一次取模 + 一次区间定位。
    eff = effective_weights(registry)
    addrs = sorted(registry.keys())          # 模型用字典序代表"注册序号"固定序
    scale = 10**6                            # 定点化（实现中权重本就是整数 wei）
    weights = [int(eff[a] * scale) for a in addrs]
    total = sum(weights)
    x = r % total
    acc = 0
    for a, wt in zip(addrs, weights):
        acc += wt
        if x < acc:
            return a
    return addrs[-1]                         # 不可达（防御性）


def lookahead(slot: int, l1_registry, l1_randao) -> str:
    # lookahead(slot) = 抽签(hash(seed(窗口), slot), 注册表快照(窗口))。
    # 注册表快照与种子取同一高度 snapshot_height(w)。
    w = window_of(slot)
    reg = l1_registry(snapshot_height(w))
    r = h(seed(w, l1_randao), slot)          # slot 间差异由 hash 派生，无需逐 slot 熵
    return weighted_pick(reg, r)


# ---------------------------------------------------------------------------
# 性质测试
# ---------------------------------------------------------------------------
PASS = []


def check(name, cond):
    assert cond, f"FAILED: {name}"
    PASS.append(name)


REG = {"alice": 100.0, "bob": 50.0, "carol": 30.0, "whale": 900.0}


def registry_at(h_snap):
    return dict(REG)                          # 快照内容只取决于高度（模型中恒定）


def randao_at(h_snap):
    return h("randao", h_snap)                # RANDAO 是快照高度的纯函数


def test_l1_determinism_and_alignment():
    a = [lookahead(s, registry_at, randao_at) for s in range(0, 2 * W_SIZE)]
    b = [lookahead(s, registry_at, randao_at) for s in range(0, 2 * W_SIZE)]
    check("L1 纯函数：任意观察者/任意时刻重算同一排班", a == b)
    w0 = {snapshot_height(window_of(s)) for s in range(0, W_SIZE)}
    check("L2 窗口对齐：窗口内所有 slot 共享唯一快照高度", len(w0) == 1)
    check("L3 相邻窗口快照高度不同（种子随窗口轮换）",
          snapshot_height(0) != snapshot_height(1))


def test_l4_snapshot_finality_geometry():
    # 前瞻可用性：现在墙钟在 slot t，t+H_LOOK 的排班要已定 ⇒ 其快照高度必须
    # 已 L1 最终化（≤ 当前 L1 头 − F_final）。对任意 t 验证该几何。
    ok = True
    for t in range(0, 4 * W_SIZE, 97):
        l1_now = l1_slot_of(t)
        far = t + H_LOOK
        ok &= snapshot_height(window_of(far)) <= l1_now - F_FINAL_L1
    check("L4 前瞻几何：未来 H_look 内任意 slot 的快照已 L1 最终化"
          "（D_snap ≥ H_look/12 + F_final + 余量）", ok)


def test_l5_weight_cap_and_proportionality():
    n = 20_000
    picks = [lookahead(s, registry_at, randao_at) for s in range(n)]
    eff = effective_weights(REG)
    total = sum(eff.values())
    freq_whale = picks.count("whale") / n
    share_whale = eff["whale"] / total        # 900 被封顶到 0.2×1080=216
    check("L5a w_max 封顶生效：90% 保证金的鲸鱼选中频率 ≈ 封顶份额（±2%）",
          abs(freq_whale - share_whale) < 0.02 and share_whale < 0.60)
    ok = all(abs(picks.count(a) / n - eff[a] / total) < 0.02 for a in REG)
    check("L5b 选中频率 ≈ 有效权重占比（全员 ±2%）", ok)


if __name__ == "__main__":
    for t in [test_l1_determinism_and_alignment,
              test_l4_snapshot_finality_geometry,
              test_l5_weight_cap_and_proportionality]:
        t()
    print("RESULTS: lookahead model — ALL PROPERTIES PASS")
    for i, name in enumerate(PASS, 1):
        print(f"  [{i:02d}] {name}")
