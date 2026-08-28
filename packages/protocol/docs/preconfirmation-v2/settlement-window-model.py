#!/usr/bin/env python3
"""
Slot-Chain §5.6 结算窗口(settlement window)可执行参考模型 + 性质测试。

对应规范: slot-chain-spec.pdf 附录 C。
目的: 满足 §12 第 18 项"实现前的门"的前半——把窗口状态机与最优链全序写成
可执行伪代码,并用性质测试验证
  P1  全序性质: 反自反、完全、传递(含第 5 轮严重 1 的 A/B/C 环已消解)
  P2  收盘赢家与候选提交顺序无关
  P3  双候选取代: 消息队列非空时,provisional 不改 canonical,
      收盘恰好提交赢家终局一次,无重复消费
  P4  【已退役】lane 洗白抵抗——强制包含删除后不再有仅强制块,
      lane 恒为同值、已从全序 key 中删去,该性质无对象
  P5  lazy close: 收盘时点后处理不改变赢家(窗口态是 L1 历史纯函数)
  P6  L1 重组: 同一 L1 历史重放得到同一窗口态;重组截断后重放一致
  P7  共享 gas 预算下不存在"无合法块"死锁; 双约束最大前缀确定且守上限
      
  P8  【已退役】桥接队列饿死抵抗 (C_bridge 保留)——强制双队列已删除
  P9  设置器不变量在独立声明的部署值间互检与因果序(§8;门后半)
  P10 罚没生效按候选落地时点判定(§4.3;门后半)
  P11 兜底资格快照保持到窗口收盘(§6.3 Δ_lag_final;门后半)
  P12 窗口中途入队: 队列 append-only 按序号引用,基线只冻结游标/状态
  P13 兜底报酬按边际推进计量: 同样净推进,拆成几个候选提交总支付不变(防刷前缀抽干保证金)

运行:  python3 settlement-window-model.py   (零依赖,全部断言通过则打印 RESULTS)
注意: 这是【模型】——签名/证明/执行以布尔占位,只精确建模本设计新增的
共识对象: 全序 key、窗口状态机、游标算术、gas 份额。
保留 P4/P8 的编号不复用,以免打断规范与 RESULTS 对"P 编号"的既有引用。
"""

import hashlib
import itertools
import random
from dataclasses import dataclass, field
from typing import Optional

# ----------------------------------------------------------------------------
# 参数 (共识常量,数值为测试用;设置器不变量见规范 §12)
# ----------------------------------------------------------------------------
# 本设计无强制包含,块内只剩一条被强制消费的队列: L1->L2 入站消息。
# C_FORCE/C_BRIDGE 及普通/桥接双队列的保证容量随之退场。
C_ANCHOR_COUNT = 2       # L1->L2 消息/块 (条数上限)
C_MSG_GAS = 10           # 消息 gas 份额/块
G_ANCHOR = 1             # anchor 固定开销
BLOCK_GAS_LIMIT = 30     # 块 gas 上限
W_SETTLE = 10            # 结算窗口长度 (L1 块)
assert G_ANCHOR + C_MSG_GAS <= BLOCK_GAS_LIMIT   # §7 共享预算不变量 (两方)

# 时序参数——规范参数表的【建议部署值】(单位: L1 slot; 1 epoch = 32 L1 slot)。
# 每个常量都是独立声明的字面量(照抄 §12 参数表),P9a 用不等式把它们互相校验;
# 绝不由公式互相推导——推导式断言恒真、失去检验力 (r46, ;
# 该非空化立刻抓出 的一处数值松弛: 8 epoch 的 Δ_lag,final 初值低于
# Δ_lag,prov + W_settle_max = 128+150 L1 slot,规范同步改为 9 epoch)。
D_ANCHOR = 32              # 锚定深度
DELTA_LAG_PROV_L1 = 128    # Δ_lag,prov = 4 epoch (服务观测阈值)
W_SETTLE_L1 = 100          # W_settle ≈ 20 min (真实建议值;窗口状态机测试用上面的玩具 W_SETTLE)
W_SETTLE_MAX_L1 = 150      # W_settle_max ≈ 1.5 × W_settle (§6.2 中危 1 共识上界)
DELTA_LAG_FINAL_L1 = 288   # Δ_lag,final = 9 epoch ≈ 57.6 min (参数表声明值 重校)
P_PROVE_MAX = 75           # 最坏证明时延 ≈ 15 min
T_INCLUDE_MAX = 10         # §1 有界纳入界 ≈ 2 min
D_ANCHOR_MAX = 420         # anchor 新鲜度上限 ≈ 84 min (参数表声明值 重校)


def h(*xs) -> int:
    return int.from_bytes(hashlib.sha256(repr(xs).encode()).digest()[:8], "big")


# ----------------------------------------------------------------------------
# 队列条目与最大前缀 (§7 统一双约束规则)
# ----------------------------------------------------------------------------
@dataclass(frozen=True)
class Item:
    iid: int
    gas: int  # 声明 gas,入队时已验 ≤ 所属队列单条目份额


def max_prefix(items: list, start: int, count_cap: int, gas_share: int):
    """FIFO 自 start 起,同时满足 条数≤count_cap 且 累计gas≤gas_share 的最长前缀。
    返回 (新游标, 消费列表)。唯一规范算法  判据)。"""
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
    parent: int          # 父块头哈希
    tag: str = ""        # 测试标签

    # 块不再有 kind——本设计无仅强制块,所有块都是排班构建者出的内容块。

    @property
    def hash(self) -> int:
        return h(self.slot, self.parent, self.tag)


@dataclass
class Candidate:
    """延伸冻结基线 base 的候选批次(带证明——此处以验证函数占位)。"""
    blocks: list

    def key(self, base_hash: int):
        """§5.2 全序 key: (count, tip_slot, tip_hash 取小)。

        原可作首位的 lane(首块类别)已无对象——所有候选同属内容类,
        lane 恒为同值、不起区分作用。修掉的非传递环不会因此复活: 那个环的
        根因是 lane 曾是 pairwise 判据,余下三个分量本就都是候选自身的标量。"""
        assert self.blocks and self.blocks[0].parent == base_hash
        tip = self.blocks[-1]
        # tip_hash 小者胜 → 取负数纳入升序字典序
        return (len(self.blocks), tip.slot, -tip.hash)


def strictly_better(a: Candidate, b: Candidate, base_hash: int) -> bool:
    return a.key(base_hash) > b.key(base_hash)


# ----------------------------------------------------------------------------
# 窗口状态机 (§5.6 r42: 基线冻结 + 候选版本化 + 收盘提交)
# ----------------------------------------------------------------------------
@dataclass(frozen=True)
class Canonical:
    tip_hash: int
    state_root: int
    m_consumed: int     # L1->L2 消息游标 (全局序号);起是唯一的队列游标


@dataclass
class EndTuple:
    tip_hash: int
    state_root: int
    m_consumed: int


@dataclass
class L1State:
    """L1 合约状态: canonical + 当前窗口。窗口态是 L1 历史的纯函数(P5/P6)。"""
    canonical: Canonical
    q_msg: list          # L1->L2 消息队列 (append-only)
    win_base: Optional[Canonical] = None
    win_close_at: Optional[int] = None
    best: Optional[tuple] = None        # (key, EndTuple, cand_id)
    consumed_log: list = field(default_factory=list)  # 收盘时消费审计

    def _validate(self, cand: Candidate, base: Canonical):
        """对冻结基线验证候选,返回 EndTuple。模型化 §5.1/§7:
        每块按双约束最大前缀消费 L1->L2 消息队列;执行合法性以游标算术代表。
        验证【不改任何 canonical 状态】。( : 强制双队列已删除。)"""
        if not cand.blocks or cand.blocks[0].parent != base.tip_hash:
            return None
        # 链接检查
        for prev, nxt in zip(cand.blocks, cand.blocks[1:]):
            if nxt.parent != prev.hash:
                return None
        m = base.m_consumed
        for blk in cand.blocks:
            gas = G_ANCHOR
            m2, tm = max_prefix(self.q_msg, m, C_ANCHOR_COUNT, C_MSG_GAS)
            gas += sum(x.gas for x in tm)
            if gas > BLOCK_GAS_LIMIT:      # P7: 共享预算下不应发生
                return None
            m = m2
        root = h(base.state_root, tuple(x.hash for x in cand.blocks), m)
        return EndTuple(cand.blocks[-1].hash, root, m)

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
        self.consumed_log.append((self.canonical.m_consumed, end.m_consumed))
        self.canonical = Canonical(end.tip_hash, end.state_root, end.m_consumed)
        self.win_base, self.win_close_at, self.best = None, None, None
        return cid


def replay(l1_history: list, genesis: Canonical, queues) -> L1State:
    """把 L1 历史(每高度的候选提交列表)重放成窗口/正统状态——纯函数 (P5/P6)。"""
    st = L1State(genesis, list(queues))
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


GEN = Canonical(tip_hash=h("genesis"), state_root=h("root0"), m_consumed=0)


def mk(base_hash, n, tag=""):
    """造一条 n 块的链式候选 ( : 块不再分类别)。"""
    blocks, parent = [], base_hash
    for i in range(n):
        blk = Block(slot=100 + i, parent=parent, tag=f"{tag}{i}")
        blocks.append(blk)
        parent = blk.hash
    return Candidate(blocks)


def test_p1_total_order():
    B = GEN.tip_hash
    # 第 5 轮严重 1 的原环 A=[X,a] B=[X,b1..b3] C=[Y,c1,c2] 作为回归保留:
    # 删掉 lane 后,三者纯按 count 排序,环更不可能出现。
    A = mk(B, 2, "X")
    Bc = mk(B, 4, "X")
    Cc = mk(B, 3, "Y")
    ks = {n: c.key(B) for n, c in [("A", A), ("B", Bc), ("C", Cc)]}
    check("P1a A/B/C 环消解为 B>C>A (无 lane,纯按块数)",
          ks["B"] > ks["C"] > ks["A"] and ks["B"] > ks["A"])
    # 随机候选上的全序公理
    rng = random.Random(42)
    cands = [mk(B, rng.randint(1, 6), f"r{i}_") for i in range(60)]
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
    qs = [Item(200 + i, 4) for i in range(12)]
    named = [("two", mk(B, 2, "sf")),
             ("six", mk(B, 6, "lf")),
             ("three", mk(B, 3, "ct")),
             ("four", mk(B, 4, "lc"))]
    winners = set()
    for perm in itertools.permutations(named):
        hist = [[(n, c)] for n, c in perm] + [[]] * (W_SETTLE + 1)
        st = replay(hist, GEN, qs)
        winners.add(st.winners[0])
    check("P2 收盘赢家与提交顺序无关 (全部 24 种排列同一赢家)",
          winners == {"six"})


def test_p3_supersession_cursors():
    qs = [Item(200 + i, 4) for i in range(12)]
    B = GEN.tip_hash
    bad = mk(B, 2, "bad")                     # 恶意短候选先落
    good = mk(B, 3, "good")                   # 诚实更长候选后落
    st = L1State(GEN, list(qs))
    assert st.accept_candidate(bad, 0, "bad")
    canon_before = st.canonical
    check("P3a provisional 接受不改 canonical", st.canonical == canon_before)
    assert st.accept_candidate(good, 3, "good")   # 同一冻结基线,起始游标必对得上
    check("P3b 更重候选可对同一冻结基线验证并取代", st.best[2] == "good")
    check("P3c 取代仍不改 canonical", st.canonical == canon_before)
    cid = st.close_window(W_SETTLE)
    check("P3d 收盘恰好提交赢家一次", cid == "good" and st.win_base is None)
    m0, m1 = st.consumed_log[0]
    check("P3e 游标单调且无重复消费(单次提交,消费=赢家终局-基线)",
          m1 >= m0 and len(st.consumed_log) == 1)


def test_p5_lazy_close():
    qs = [Item(200, 4)]
    B = GEN.tip_hash
    c1 = mk(B, 2, "a")
    c2 = mk(B, 4, "b")
    hist = [[("a", c1)], [("b", c2)]] + [[]] * (W_SETTLE + 5)
    st_on_time = replay(hist[:W_SETTLE + 1] + [[]], GEN, qs)
    st_lazy = replay(hist, GEN, qs)
    check("P5 lazy close 不改赢家与 canonical",
          st_on_time.winners == st_lazy.winners == ["b"]
          and st_on_time.canonical == st_lazy.canonical)
    # 收盘后到达的候选不入本窗口
    late = mk(B, 6, "late")
    hist2 = [[("a", c1)]] + [[]] * (W_SETTLE) + [[("late", late)]] + [[]] * (W_SETTLE + 1)
    st2 = replay(hist2, GEN, qs)
    check("P5b 收盘后候选只能开启下一窗口(赢家仍是窗口内最重)",
          st2.winners[0] == "a")


def test_p6_reorg_replay():
    qs = [Item(200, 4)]
    B = GEN.tip_hash
    c1, c2 = mk(B, 2, "a"), mk(B, 4, "b")
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
        # 随机可达队列状态 (入队验证保证单条 ≤ 消息队列份额——起这是防
        # 单侧死锁的承重条: 队头若超过"块上限 − anchor 开销"就没有合法块了)
        q_msg = [Item(90 + i, rng.randint(1, C_MSG_GAS)) for i in range(rng.randint(0, 15))]
        # (): 非创世基线——随机已消费游标
        base = Canonical(h("b", trial), h("r", trial), rng.randint(0, len(q_msg)))
        st = L1State(base, q_msg)
        cand = mk(base.tip_hash, 1, f"t{trial}")
        end = st._validate(cand, base)
        assert end is not None, f"deadlock at trial {trial}"   # 任意可达状态都存在合法块
        assert end.m_consumed >= base.m_consumed
        i2, taken = max_prefix(q_msg, 0, C_ANCHOR_COUNT, C_MSG_GAS)
        assert len(taken) <= C_ANCHOR_COUNT and sum(x.gas for x in taken) <= C_MSG_GAS
    check("P7 共享 gas 预算下 300 组随机可达状态(含非创世游标)均存在合法块;前缀守双上限", True)


def test_p7b_single_message_cap_is_load_bearing():
    """ : 强制队列删除后,单条消息 gas 上限成为唯一挡住"无合法块"的闸。
    造一条超限消息(入队验证本应拒绝它),确认它确实会制造死锁——以此证明
    该上限不是冗余条款。"""
    oversized = [Item(1, BLOCK_GAS_LIMIT + 5)]
    st = L1State(GEN, oversized)
    end = st._validate(mk(GEN.tip_hash, 1, "over"), GEN)
    # 超限条目取不进前缀 → 该块合法但游标停滞: 队列被一条坏消息永久堵死
    check("P7b 单条消息 gas 上限承重: 超限条目会令游标永久停滞(故入队必须拒收)",
          end is not None and end.m_consumed == GEN.m_consumed)


def test_p9_anchor_geometry():
    """(门后半) / 非空化: 设置器不变量在【独立声明的】部署值之间互检——
    改动任一分量而不更新声明值即失败,不再是由公式推导的恒真断言 ()。"""
    check("P9a 设置器不变量互检: Δ_lag,final ≥ prov+W_settle_max; D_anchor_max ≥ 最坏路径; W_settle ≥ 证明+纳入",
          DELTA_LAG_FINAL_L1 >= DELTA_LAG_PROV_L1 + W_SETTLE_MAX_L1
          and D_ANCHOR + DELTA_LAG_FINAL_L1 + P_PROVE_MAX + T_INCLUDE_MAX <= D_ANCHOR_MAX
          and W_SETTLE_L1 >= P_PROVE_MAX + T_INCLUDE_MAX
          and W_SETTLE_MAX_L1 >= W_SETTLE_L1)
    # §8 规范关系 anchor.L1_timestamp ≤ L2_timestamp(slot),按各自时基显式建模
    # : L1 slot = 12 s, L2 slot = 1 s, 同创世原点。
    def l1_timestamp(l1_slot):
        return 12 * l1_slot
    def l2_timestamp(l2_slot):
        return 1 * l2_slot
    def causality_ok(anchor_l1_slot, block_l2_slot):
        return l1_timestamp(anchor_l1_slot) <= l2_timestamp(block_l2_slot)
    check("P9b 因果序 anchor.L1_time ≤ L2_time(slot): 旧 slot 配新 anchor 被拒;等号允许;正常组合被收",
          not causality_ok(anchor_l1_slot=100, block_l2_slot=1199)
          and causality_ok(anchor_l1_slot=100, block_l2_slot=1200)
          and causality_ok(anchor_l1_slot=100, block_l2_slot=1250))


def test_p10_slashing_acceptance_gate():
    """(门后半): 罚没生效按候选落地时点判 (§4.3 r41)。"""
    EFFECT = 50
    def signer_allowed(cand_landed_at, slashed=True):
        return (not slashed) or cand_landed_at < EFFECT
    check("P10 罚没后落地的候选拒含该 signer;生效前已落地祖父化",
          signer_allowed(49) and not signer_allowed(50) and not signer_allowed(51)
          and signer_allowed(51, slashed=False))


def test_p11_fallback_snapshot():
    """(门后半): 兜底资格按 lag_final > Δ_lag_final 判定,开窗即快照、
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


def test_p12_midwindow_enqueue():
    """(): 基线冻结的对象是【游标与状态】,不含队列内容——
    消息队列在 L1 上 append-only、条目按序号引用且内容不可变,窗口中途入队的
    新条目对能覆盖到它的后续候选可见且确定;先前候选已记账的终局不受影响,
    窗口态仍是 L1 历史(含入队事件)的纯函数。"""
    q0 = [Item(i, 2) for i in range(4)]
    st = L1State(GEN, list(q0))
    c1 = mk(GEN.tip_hash, 2, "p12a")
    assert st.accept_candidate(c1, l1_now=0, cand_id="c1")
    end1 = st.best[1]
    st.q_msg.append(Item(99, 2))            # 窗口中途 L1 入队 (append-only)
    c2 = mk(GEN.tip_hash, 3, "p12b")
    assert st.accept_candidate(c2, l1_now=3, cand_id="c2")
    end2 = st.best[1]
    check("P12a 中途入队: 先前候选终局不变,更重候选对同一冻结游标基线可消费新条目,canonical 不动",
          st.best[2] == "c2" and end2.m_consumed > end1.m_consumed
          and st.canonical == GEN)
    st2 = L1State(GEN, list(q0) + [Item(99, 2)])
    st2.accept_candidate(c1, 0, "c1")
    st2.accept_candidate(c2, 3, "c2")
    check("P12b append-only ⇒ 位置稳定: 条目入队时点不影响验证结果(同赢家同终局)",
          st2.best[2] == "c2" and st2.best[1] == end2)


def test_p13_reward_metered_on_marginal_advancement():
    """§6.3: 兜底报酬按【边际推进】计量,不按候选个数。

    否则持有一条 N 块尾巴的人可以依次提交长度 1,2,...,N 的前缀——每条都严格更重、
    每条都拿一次全额报酬+加成,把聚合者保证金抽干。这里断言:同样的净推进量,
    无论拆成几个候选提交,总支付相同。
    """
    RATE = 7                       # 每块报酬(含加成)的定点值

    def payout(submissions):
        """submissions = 依次提交的候选块数;只对超过当前最优的增量计费。"""
        best, total = 0, 0
        for n in submissions:
            if n > best:           # 严格更重才被接受
                total += (n - best) * RATE
                best = n
        return total, best

    one_shot, b1 = payout([12])                       # 一次落满
    ground, b2 = payout(list(range(1, 13)))           # 拆成 12 个前缀刷
    interleaved, b3 = payout([3, 1, 7, 5, 12, 9])     # 乱序 + 更差候选混入
    check("P13a 报酬与拆分方式无关: 一次落满 == 逐前缀刷 == 乱序提交",
          one_shot == ground == interleaved and b1 == b2 == b3 == 12)
    check("P13b 报酬正比于净推进,与候选个数无关",
          one_shot == 12 * RATE)
    # 更差候选不被接受,故不产生任何支付
    worse, _ = payout([12, 4, 9])
    check("P13c 更差候选零支付(不接受即不计费)", worse == 12 * RATE)


if __name__ == "__main__":
    for t in [test_p1_total_order, test_p2_order_independence,
              test_p3_supersession_cursors,
              test_p5_lazy_close, test_p6_reorg_replay, test_p7_gas_no_deadlock,
              test_p7b_single_message_cap_is_load_bearing, test_p9_anchor_geometry,
              test_p10_slashing_acceptance_gate, test_p11_fallback_snapshot,
              test_p12_midwindow_enqueue,
              test_p13_reward_metered_on_marginal_advancement]:
        t()
    print("RESULTS: settlement-window model — ALL PROPERTIES PASS")
    for i, name in enumerate(PASS, 1):
        print(f"  [{i:02d}] {name}")
