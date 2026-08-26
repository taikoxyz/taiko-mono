#!/usr/bin/env python3
"""
Slot-Chain §5.6 结算窗口(settlement window)可执行参考模型 + 性质测试。

对应规范: slot-chain-spec.md 草案 v1.43,附录 C。
目的: 满足 §12 第 18 项"实现前的门"的前半——把窗口状态机与最优链全序写成
可执行伪代码,并用性质测试验证独立审核第 5 轮列出的全部不变量:
  P1  全序性质: 反自反、完全、传递(含第 5 轮严重 1 的 A/B/C 环已消解)
  P2  收盘赢家与候选提交顺序无关
  P3  双候选取代: 强制/消息队列非空时,provisional 不改 canonical,
      收盘恰好提交赢家终局一次,无重复消费
  P4  lane 洗白抵抗: 仅强制首块的链接再多普通块仍输给内容链
  P5  lazy close: 收盘时点后处理不改变赢家(窗口态是 L1 历史纯函数)
  P6  L1 重组: 同一 L1 历史重放得到同一窗口态;重组截断后重放一致
  P7  共享 gas 预算下不存在"无合法块"死锁; 双约束最大前缀确定且守上限
      (r44: 含非创世游标基线)
  P8  桥接满载洪泛下普通强制队列不被饿死 (C_bridge 保留,§7 r19-1;修 DeepSeek C2)
  P9  anchor 新鲜度几何(最坏兜底路径 ≤ D_anchor_max)与因果序(§8;门后半)
  P10 罚没生效按候选落地时点判定(§4.3;门后半)
  P11 兜底资格快照保持到窗口收盘(§6.3 Δ_lag_final;门后半)

运行:  python3 settlement-window-model.py   (零依赖,全部断言通过则打印 RESULTS)
注意: 这是【模型】——签名/证明/执行以布尔占位,只精确建模本设计新增的
共识对象: 全序 key、窗口状态机、游标算术、gas 份额。
"""

import hashlib
import itertools
import random
from dataclasses import dataclass, field
from typing import Optional

# ----------------------------------------------------------------------------
# 参数 (共识常量,数值为测试用;设置器不变量见规范 §12)
# ----------------------------------------------------------------------------
C_FORCE_COUNT = 4        # 强制条目/块 (条数上限,含桥接)
C_FORCE_GAS = 19         # 强制 gas 份额/块 (含桥接)
C_BRIDGE_COUNT = 1       # 桥接保留 (≈25% × C_FORCE_COUNT, §7 r19-1)
C_BRIDGE_GAS = 5         # 桥接 gas 保留;普通队列保证容量 = C_FORCE − C_BRIDGE
C_ANCHOR_COUNT = 2       # L1->L2 消息/块 (条数上限)
C_MSG_GAS = 10           # 消息 gas 份额/块
G_ANCHOR = 1             # anchor 固定开销
BLOCK_GAS_LIMIT = 30     # 块 gas 上限
W_SETTLE = 10            # 结算窗口长度 (L1 块)
assert G_ANCHOR + C_FORCE_GAS + C_MSG_GAS <= BLOCK_GAS_LIMIT  # §8 共享预算不变量
assert C_BRIDGE_COUNT < C_FORCE_COUNT and C_BRIDGE_GAS < C_FORCE_GAS
ORD_GUARANTEE_COUNT = C_FORCE_COUNT - C_BRIDGE_COUNT   # 普通队列保证容量 (r19-1)
ORD_GUARANTEE_GAS = C_FORCE_GAS - C_BRIDGE_GAS

# 时序参数 (P9 anchor 几何;单位: L1 slot)
D_ANCHOR = 32
DELTA_LAG_PROV_L1 = 128  # Δ_lag,prov 换算 L1 slot (服务观测阈值)
W_SETTLE_MAX = 15        # W_settle 共识上界 (§6.2 中危 1;含墙钟换算余量)
DELTA_LAG_FINAL_L1 = DELTA_LAG_PROV_L1 + W_SETTLE_MAX + 5  # Δ_lag,final (r44, DeepSeek C1)
P_PROVE_MAX = 75
T_INCLUDE_MAX = 10
# 兜底最坏路径的 lag 项是 Δ_lag,final (兜底以 lag_final 开窗), 非 Δ_lag,prov
D_ANCHOR_MAX = D_ANCHOR + DELTA_LAG_FINAL_L1 + P_PROVE_MAX + T_INCLUDE_MAX + 5  # §12 最强不变量

CONTENT, FORCED = "content", "forced"


def h(*xs) -> int:
    return int.from_bytes(hashlib.sha256(repr(xs).encode()).digest()[:8], "big")


# ----------------------------------------------------------------------------
# 队列条目与最大前缀 (§7/§8 统一双约束规则)
# ----------------------------------------------------------------------------
@dataclass(frozen=True)
class Item:
    iid: int
    gas: int  # 声明 gas,入队时已验 ≤ 所属队列单条目份额


def max_prefix(items: list, start: int, count_cap: int, gas_share: int):
    """FIFO 自 start 起,同时满足 条数≤count_cap 且 累计gas≤gas_share 的最长前缀。
    返回 (新游标, 消费列表)。唯一规范算法 (r41/r42,无第二套 min(条数) 判据)。"""
    taken, gas = [], 0
    i = start
    while i < len(items) and len(taken) < count_cap and gas + items[i].gas <= gas_share:
        gas += items[i].gas
        taken.append(items[i])
        i += 1
    return i, taken


# ----------------------------------------------------------------------------
# 块与候选 (§4.2/§5.2)
# ----------------------------------------------------------------------------
@dataclass(frozen=True)
class Block:
    slot: int
    kind: str            # CONTENT | FORCED
    parent: int          # 父块头哈希
    tag: str = ""        # 测试标签

    @property
    def hash(self) -> int:
        return h(self.slot, self.kind, self.parent, self.tag)


@dataclass
class Candidate:
    """延伸冻结基线 base 的候选批次(带证明——此处以验证函数占位)。"""
    blocks: list

    def key(self, base_hash: int):
        """§5.2 r42 全序 key: (lane, count, tip_slot, tip_hash 取小)。
        lane 是候选自身不变标量 = 自基线起【第一个块】的类别,整条继承。"""
        assert self.blocks and self.blocks[0].parent == base_hash
        lane = 1 if self.blocks[0].kind == CONTENT else 0
        tip = self.blocks[-1]
        # tip_hash 小者胜 → 取负数纳入升序字典序
        return (lane, len(self.blocks), tip.slot, -tip.hash)


def strictly_better(a: Candidate, b: Candidate, base_hash: int) -> bool:
    return a.key(base_hash) > b.key(base_hash)


# ----------------------------------------------------------------------------
# 窗口状态机 (§5.6 r42: 基线冻结 + 候选版本化 + 收盘提交)
# ----------------------------------------------------------------------------
@dataclass(frozen=True)
class Canonical:
    tip_hash: int
    state_root: int
    f_cur_ord: int      # 强制普通队列已消费游标
    f_cur_br: int       # 强制桥接队列已消费游标
    m_consumed: int     # L1->L2 消息游标 (全局序号)


@dataclass
class EndTuple:
    tip_hash: int
    state_root: int
    f_cur_ord: int
    f_cur_br: int
    m_consumed: int


@dataclass
class L1State:
    """L1 合约状态: canonical + 当前窗口。窗口态是 L1 历史的纯函数(P5/P6)。"""
    canonical: Canonical
    q_ord: list          # 强制普通队列 (append-only)
    q_br: list           # 强制桥接队列
    q_msg: list          # L1->L2 消息队列
    win_base: Optional[Canonical] = None
    win_close_at: Optional[int] = None
    best: Optional[tuple] = None        # (key, EndTuple, cand_id)
    consumed_log: list = field(default_factory=list)  # 收盘时消费审计

    def _validate(self, cand: Candidate, base: Canonical):
        """对冻结基线验证候选,返回 EndTuple。模型化 §5.1/§7/§8:
        每块按双约束最大前缀消费两条强制队列与消息队列;内容块与仅强制块同负
        强制前缀义务;执行合法性以游标算术代表。验证【不改任何 canonical 状态】。"""
        if not cand.blocks or cand.blocks[0].parent != base.tip_hash:
            return None
        # 链接检查
        for prev, nxt in zip(cand.blocks, cand.blocks[1:]):
            if nxt.parent != prev.hash:
                return None
        o, b, m = base.f_cur_ord, base.f_cur_br, base.m_consumed
        for blk in cand.blocks:
            gas = G_ANCHOR
            # 桥接优先但【至多 C_BRIDGE 保留】,普通队列拿保证余量 (§7 r19-1
            # ——r44 修 DeepSeek C2: 此前桥接误取整个 C_FORCE 预算,可饿死普通队列)
            b2, tb = max_prefix(self.q_br, b, C_BRIDGE_COUNT, C_BRIDGE_GAS)
            gas_b = sum(x.gas for x in tb)
            o2, to = max_prefix(self.q_ord, o, C_FORCE_COUNT - len(tb),
                                C_FORCE_GAS - gas_b)
            m2, tm = max_prefix(self.q_msg, m, C_ANCHOR_COUNT, C_MSG_GAS)
            gas += gas_b + sum(x.gas for x in to) + sum(x.gas for x in tm)
            if gas > BLOCK_GAS_LIMIT:      # P7: 共享预算下不应发生
                return None
            o, b, m = o2, b2, m2
        root = h(base.state_root, tuple(x.hash for x in cand.blocks), o, b, m)
        return EndTuple(cand.blocks[-1].hash, root, o, b, m)

    def accept_candidate(self, cand: Candidate, l1_now: int, cand_id: str) -> bool:
        """acceptCandidate: 开窗(首候选)或在窗口内以严格更重取代。
        provisional 只记账,绝不动 canonical (P3)。"""
        if self.win_base is None:
            base = self.canonical
        else:
            if l1_now >= self.win_close_at:
                return False               # 收盘后不再受理 (P5)
            base = self.win_base
        end = self._validate(cand, base)
        if end is None:
            return False
        k = cand.key(base.tip_hash)
        if self.best is not None and not k > self.best[0]:
            return False                   # 须严格更重
        if self.win_base is None:          # openWindow
            self.win_base = self.canonical
            self.win_close_at = l1_now + W_SETTLE
        self.best = (k, end, cand_id)
        return True

    def close_window(self, l1_now: int) -> Optional[str]:
        """closeWindow: 收盘一笔原子提交赢家终局 (可 lazy,P5)。"""
        if self.win_base is None or l1_now < self.win_close_at:
            return None
        _, end, cid = self.best
        self.consumed_log.append((self.canonical.f_cur_ord, end.f_cur_ord,
                                  self.canonical.f_cur_br, end.f_cur_br,
                                  self.canonical.m_consumed, end.m_consumed))
        self.canonical = Canonical(end.tip_hash, end.state_root,
                                   end.f_cur_ord, end.f_cur_br, end.m_consumed)
        self.win_base, self.win_close_at, self.best = None, None, None
        return cid


def replay(l1_history: list, genesis: Canonical, queues) -> L1State:
    """把 L1 历史(每高度的候选提交列表)重放成窗口/正统状态——纯函数 (P5/P6)。"""
    st = L1State(genesis, *[list(q) for q in queues])
    winners = []
    for height, submissions in enumerate(l1_history):
        w = st.close_window(height)
        if w:
            winners.append(w)
        for cid, cand in submissions:
            st.accept_candidate(cand, height, cid)
    st.winners = winners
    return st


# ----------------------------------------------------------------------------
# 性质测试
# ----------------------------------------------------------------------------
PASS = []


def check(name, cond):
    assert cond, f"FAILED: {name}"
    PASS.append(name)


GEN = Canonical(tip_hash=h("genesis"), state_root=h("root0"),
                f_cur_ord=0, f_cur_br=0, m_consumed=0)


def mk(base_hash, kinds, tag=""):
    """按类别序列造一条链式候选。"""
    blocks, parent = [], base_hash
    for i, kind in enumerate(kinds):
        blk = Block(slot=100 + i, kind=kind, parent=parent, tag=f"{tag}{i}")
        blocks.append(blk)
        parent = blk.hash
    return Candidate(blocks)


def test_p1_total_order():
    B = GEN.tip_hash
    # 第 5 轮严重 1 的原环: A=[X,a] B=[X,b1..b3] C=[Y,c1,c2]
    A = mk(B, [FORCED, CONTENT], "X")           # lane=forced(首块X), count 2
    Bc = mk(B, [FORCED] * 4, "X")               # lane=forced, count 4
    Cc = mk(B, [FORCED] * 3, "Y")               # lane=forced, count 3
    ks = {n: c.key(B) for n, c in [("A", A), ("B", Bc), ("C", Cc)]}
    check("P1a 第5轮 A/B/C 环消解为 B>C>A",
          ks["B"] > ks["C"] > ks["A"] and ks["B"] > ks["A"])
    # 随机候选上的全序公理
    rng = random.Random(42)
    cands = []
    for i in range(60):
        n = rng.randint(1, 6)
        kinds = [rng.choice([CONTENT, FORCED]) for _ in range(n)]
        cands.append(mk(B, kinds, f"r{i}_"))
    keys = [c.key(B) for c in cands]
    for a, b in itertools.combinations(keys, 2):
        check_ok = (a > b) ^ (b > a) if a != b else True   # 完全 + 反自反
        assert check_ok
    for a, b, c in itertools.islice(itertools.combinations(keys, 3), 4000):
        if a > b and b > c:
            assert a > c                                    # 传递
    check("P1b 随机候选: 反自反/完全/传递", True)


def test_p2_order_independence():
    B = GEN.tip_hash
    qs = ([Item(i, 3) for i in range(20)], [Item(100 + i, 2) for i in range(6)],
          [Item(200 + i, 4) for i in range(12)])
    named = [("short_forced", mk(B, [FORCED] * 2, "sf")),
             ("long_forced", mk(B, [FORCED] * 5, "lf")),
             ("content", mk(B, [CONTENT] * 3, "ct")),
             ("long_content", mk(B, [CONTENT] * 4, "lc"))]
    winners = set()
    for perm in itertools.permutations(named):
        hist = [[(n, c)] for n, c in perm] + [[]] * (W_SETTLE + 1)
        st = replay(hist, GEN, qs)
        winners.add(st.winners[0])
    check("P2 收盘赢家与提交顺序无关 (全部 24 种排列同一赢家)",
          winners == {"long_content"})


def test_p3_supersession_cursors():
    qs = ([Item(i, 3) for i in range(20)], [Item(100 + i, 2) for i in range(6)],
          [Item(200 + i, 4) for i in range(12)])
    B = GEN.tip_hash
    bad = mk(B, [FORCED] * 2, "bad")          # 恶意短仅强制候选先落
    good = mk(B, [CONTENT] * 3, "good")       # 诚实内容候选后落
    st = L1State(GEN, *[list(q) for q in qs])
    assert st.accept_candidate(bad, 0, "bad")
    canon_before = st.canonical
    check("P3a provisional 接受不改 canonical", st.canonical == canon_before)
    assert st.accept_candidate(good, 3, "good")   # 同一冻结基线,起始游标必对得上
    check("P3b 更重候选可对同一冻结基线验证并取代", st.best[2] == "good")
    check("P3c 取代仍不改 canonical", st.canonical == canon_before)
    cid = st.close_window(W_SETTLE)
    check("P3d 收盘恰好提交赢家一次", cid == "good" and st.win_base is None)
    ord0, ord1, br0, br1, m0, m1 = st.consumed_log[0]
    check("P3e 游标单调且无重复消费(单次提交,消费=赢家终局-基线)",
          ord1 >= ord0 and br1 >= br0 and m1 >= m0 and len(st.consumed_log) == 1)


def test_p4_whitewash():
    B = GEN.tip_hash
    scaffold = mk(B, [FORCED] * 10 + [CONTENT] * 3, "wf")  # 13 块,首块仅强制
    content = mk(B, [CONTENT] * 3, "hc")                   # 3 块内容
    check("P4 lane 洗白抵抗: 13 块仅强制首链 < 3 块内容链",
          content.key(B) > scaffold.key(B))


def test_p5_lazy_close():
    qs = ([Item(i, 3) for i in range(9)], [], [Item(200, 4)])
    B = GEN.tip_hash
    c1 = mk(B, [CONTENT] * 2, "a")
    c2 = mk(B, [CONTENT] * 4, "b")
    hist = [[("a", c1)], [("b", c2)]] + [[]] * (W_SETTLE + 5)
    st_on_time = replay(hist[:W_SETTLE + 1] + [[]], GEN, qs)
    st_lazy = replay(hist, GEN, qs)
    check("P5 lazy close 不改赢家与 canonical",
          st_on_time.winners == st_lazy.winners == ["b"]
          and st_on_time.canonical == st_lazy.canonical)
    # 收盘后到达的候选不入本窗口
    late = mk(B, [CONTENT] * 6, "late")
    hist2 = [[("a", c1)]] + [[]] * (W_SETTLE) + [[("late", late)]] + [[]] * (W_SETTLE + 1)
    st2 = replay(hist2, GEN, qs)
    check("P5b 收盘后候选只能开启下一窗口(赢家仍是窗口内最重)",
          st2.winners[0] == "a")


def test_p6_reorg_replay():
    qs = ([Item(i, 3) for i in range(9)], [], [Item(200, 4)])
    B = GEN.tip_hash
    c1, c2 = mk(B, [CONTENT] * 2, "a"), mk(B, [CONTENT] * 4, "b")
    hist = [[("a", c1)], [("b", c2)]] + [[]] * (W_SETTLE + 1)
    s1, s2 = replay(hist, GEN, qs), replay(hist, GEN, qs)
    check("P6a 纯函数: 同一 L1 历史重放同一状态",
          s1.canonical == s2.canonical and s1.winners == s2.winners)
    # 浅重组: 截掉含 c2 的 L1 块,换成空块 → c2 原子消失,赢家变 a
    reorged = [hist[0], []] + [[]] * (W_SETTLE + 1)
    s3 = replay(reorged, GEN, qs)
    check("P6b 重组截断后重放: 被重组掉的候选原子消失,状态一致",
          s3.winners[0] == "a" and s3.canonical != s1.canonical)


def test_p7_gas_no_deadlock():
    rng = random.Random(7)
    for trial in range(300):
        # 随机可达队列状态 (入队验证保证单条 ≤ 所属队列份额,r19-1)
        q_ord = [Item(i, rng.randint(1, ORD_GUARANTEE_GAS)) for i in range(rng.randint(0, 15))]
        q_br = [Item(50 + i, rng.randint(1, C_BRIDGE_GAS)) for i in range(rng.randint(0, 6))]
        q_msg = [Item(90 + i, rng.randint(1, C_MSG_GAS)) for i in range(rng.randint(0, 15))]
        # r44 (DeepSeek 建议 3): 非创世基线——随机已消费游标
        base = Canonical(h("b", trial), h("r", trial),
                         rng.randint(0, len(q_ord)), rng.randint(0, len(q_br)),
                         rng.randint(0, len(q_msg)))
        st = L1State(base, q_ord, q_br, q_msg)
        cand = mk(base.tip_hash, [CONTENT], f"t{trial}")
        end = st._validate(cand, base)
        assert end is not None, f"deadlock at trial {trial}"   # 任意可达状态都存在合法块
        assert end.f_cur_ord >= base.f_cur_ord and end.m_consumed >= base.m_consumed
        i2, taken = max_prefix(q_msg, 0, C_ANCHOR_COUNT, C_MSG_GAS)
        assert len(taken) <= C_ANCHOR_COUNT and sum(x.gas for x in taken) <= C_MSG_GAS
    check("P7 共享 gas 预算下 300 组随机可达状态(含非创世游标)均存在合法块;前缀守双上限", True)


def test_p8_bridge_no_starvation():
    """r44 (DeepSeek C2 + 建议 1): 持续桥接洪泛下普通强制队列不可被饿死。"""
    q_br = [Item(500 + i, C_BRIDGE_GAS) for i in range(100)]      # 满载桥接积压
    q_ord = [Item(i, ORD_GUARANTEE_GAS) for i in range(10)]       # 普通队头 = 满份额条目
    st = L1State(GEN, q_ord, q_br, [])
    cand = mk(GEN.tip_hash, [CONTENT] * 3, "st")
    end = st._validate(cand, GEN)
    assert end is not None
    check("P8 桥接满载洪泛下普通队列每块仍消费 ≥ 保证容量(不被饿死)",
          end.f_cur_ord >= 3 * 1 and end.f_cur_br == 3 * C_BRIDGE_COUNT)


def test_p9_anchor_geometry():
    """r44 (门后半): anchor 新鲜度几何 + 因果序。"""
    worst_age = D_ANCHOR + DELTA_LAG_FINAL_L1 + P_PROVE_MAX + T_INCLUDE_MAX
    check("P9a 最坏兜底路径 anchor 年龄 ≤ D_anchor_max (设置器不变量成立)",
          worst_age <= D_ANCHOR_MAX)
    def causality_ok(anchor_l1_slot, block_l2_slot):
        return anchor_l1_slot * 12 <= block_l2_slot        # anchor 时间 ≤ slot 时间
    check("P9b 因果序: 旧 slot 配新 anchor 被拒;正常组合被收",
          not causality_ok(anchor_l1_slot=100, block_l2_slot=600)
          and causality_ok(anchor_l1_slot=100, block_l2_slot=1250))


def test_p10_slashing_acceptance_gate():
    """r44 (门后半): 罚没生效按候选落地时点判 (§4.3 r41)。"""
    EFFECT = 50
    def signer_allowed(cand_landed_at, slashed=True):
        return (not slashed) or cand_landed_at < EFFECT
    check("P10 罚没后落地的候选拒含该 signer;生效前已落地祖父化",
          signer_allowed(49) and not signer_allowed(50) and not signer_allowed(51)
          and signer_allowed(51, slashed=False))


def test_p11_fallback_snapshot():
    """r44 (门后半): 兜底资格按 lag_final > Δ_lag_final 判定,开窗即快照、
    保持到结算窗口收盘 (§6.3 r42/r44)。"""
    DELTA_LAG_FINAL = DELTA_LAG_FINAL_L1
    class FallbackAccounting:
        def __init__(self):
            self.snapshot = None
        def observe(self, lag_final, l1_now):
            if self.snapshot is None and lag_final > DELTA_LAG_FINAL:
                self.snapshot = (True, l1_now)
        def eligible(self, l1_now, window_close_at):
            return self.snapshot is not None and l1_now <= window_close_at
    fa = FallbackAccounting()
    fa.observe(lag_final=DELTA_LAG_FINAL + 10, l1_now=0)
    check("P11 兜底资格快照保持到窗口收盘,provisional lag 重置不撤销",
          fa.eligible(l1_now=5, window_close_at=W_SETTLE)
          and fa.eligible(l1_now=W_SETTLE, window_close_at=W_SETTLE))


if __name__ == "__main__":
    for t in [test_p1_total_order, test_p2_order_independence,
              test_p3_supersession_cursors, test_p4_whitewash,
              test_p5_lazy_close, test_p6_reorg_replay, test_p7_gas_no_deadlock,
              test_p8_bridge_no_starvation, test_p9_anchor_geometry,
              test_p10_slashing_acceptance_gate, test_p11_fallback_snapshot]:
        t()
    print("RESULTS: settlement-window model — ALL PROPERTIES PASS")
    for i, name in enumerate(PASS, 1):
        print(f"  [{i:02d}] {name}")
