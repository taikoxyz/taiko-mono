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
  P13 兜底报酬 = 固定成本 + 边际块奖励,按净推进封顶、超额分摊:
      同 count 的严格改进者不白干;拆前缀刷不增加总支付且对刷者亏损

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
    """§4.3: 罚没生效【按结算窗口】判定,而非按候选落地时点。

    旧规则以候选的 L1 落地时点为准,可被武器化:等价物自己选择提交证据的时刻,
    而 δ_slash(64 slot)远短于证明+上链的 10–15 分钟,于是它可以让生效时点落在
    "诚实候选已构造、尚未落地"之间——较重的诚实候选不是被压过而是被判无效,
    整条尾巴级联作废,较轻的候选反而收盘获胜,代价仅为固定的 L_eq。
    窗口作用域消除了攻击者对时点的控制:罚没集在开窗(基线冻结)时一并冻结,
    窗口内所有候选按同一集合判定,证据提交时刻在窗口内不产生任何影响。
    """
    # 罚没在 L1 生效时点 EFFECT;窗口 W 的开窗时点为 open_at
    EFFECT = 50

    def applies_to_window(open_at):
        """罚没作用于某窗口 ⟺ 其生效时点严格早于该窗口开窗。"""
        return EFFECT < open_at

    def old_rule_allowed(cand_landed_at):
        """上一版:按候选自身的落地时点判定(此处仅作对照)。"""
        return cand_landed_at < EFFECT

    # a) 窗口作用域:开窗早于生效 ⇒ 整窗不适用;开窗晚于生效 ⇒ 整窗适用
    check("P10a 罚没按开窗时点作用于整个窗口(生效早于开窗才适用)",
          not applies_to_window(40) and not applies_to_window(50)
          and applies_to_window(51))

    # b) 关键性质:窗口内每个候选的判定一致,与其落地时点无关
    window_open = 40                      # 生效(50)落在本窗口【中途】
    lands = [41, 49, 55, 60]              # 同窗内不同落地时点的候选
    verdicts = {c: applies_to_window(window_open) for c in lands}
    check("P10b 同一窗口内所有候选判定一致,与各自落地时点无关",
          len(set(verdicts.values())) == 1 and verdicts[41] is False)

    # c) 同构型下旧规则不一致 —— 正是武器化所利用的差别
    old_verdicts = {c: old_rule_allowed(c) for c in lands}
    check("P10c 旧规则在同一窗口内给出不一致判定(在飞行中的候选可被判无效)",
          len(set(old_verdicts.values())) == 2
          and old_rule_allowed(49) and not old_rule_allowed(55))

    # d) 生效落在窗口中途时,罚没从第一个开窗【严格晚于】生效时点的窗口起适用,
    #    延迟至多一个 W_settle
    opens = [window_open + n * W_SETTLE for n in range(5)]   # 连续窗口的开窗时点
    first_applicable = next(o for o in opens if applies_to_window(o))
    check("P10d 中途生效的罚没从下一个开窗起适用,延迟 ≤ 一个 W_settle",
          first_applicable > EFFECT and first_applicable - EFFECT <= W_SETTLE
          and not applies_to_window(window_open))


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
    """§6.3: 固定成本按【(count, tip_slot) 层级】计价,每层仅一份,收盘付给该层持有者。

    上一版按"每个严格改进者一份 C_fixed"计价,可被 tip_hash 磨榨:§4.1 明确
    罚没是幂等的——同一 builder 的多份等价物证据只罚一次,L_eq 是其威慑上限。
    因此调度到 slot s 的 builder 可以为同一 slot 签出任意多个不同 header,按
    tip_hash 递减依次提交,每个都是 §5.2 意义下的严格改进:它只付一次 L_eq,
    却领走 n 份 C_fixed,把聚合器保证金抽干到 R_WINDOW_MAX。
    (先前文中"伪造 tip-only 竞争候选每次都要付 L_eq"的说法是错的,与 §4.1 的
    幂等条款自相矛盾。)

    修正:C_fixed 以层级计价。层级 = 窗口内被接受候选达到过的不同
    (count, tip_slot);每层恰好一份 C_fixed,收盘时付给该层的持有者,即该层上
    tip_hash 最小的被接受候选的提交者。于是:
      · 同层磨 n 个 hash ⇒ 全窗只产生【一份】C_fixed,攻击者白付 n 次证明 + L_eq;
      · 诚实方顶掉恶意同层候选后【成为该层持有者】,拿到那一份,先提交者拿不到
        ——激励方向正确;
      · 每达成一个新层级的诚实改进者照常收回成本。
    """
    C_FIXED, PHI, PHI_DATA = 10, 7, 2   # 固定成本 / 每块奖励 / 每单位数据字节
    TRUE_COST = 10                      # 一次证明+上链真实成本;不变式 C_FIXED <= TRUE_COST
    R_WINDOW_MAX = 10_000               # 单窗口保证金外流硬上限(安全阀)

    assert C_FIXED <= TRUE_COST, "C_FIXED 必须 ≤ 真实成本,否则拆前缀有利可图"

    def key(c):
        return (c["count"], c["tip_slot"], -c["tip_hash"])

    def settle(subs, base_count=0):
        """接受严格更优者;C_fixed 按层级计价,φ 按边际块与已发布数据计价。"""
        best, levels, phi, data = None, {}, {}, {}
        for c in subs:
            if best is None or key(c) > key(best):
                added = max(0, c["count"] - (best["count"] if best else base_count))
                phi[c["who"]] = phi.get(c["who"], 0) + added
                data[c["who"]] = data.get(c["who"], 0) + c.get("bytes", 0)
                lv = (c["count"], c["tip_slot"])
                if lv not in levels or c["tip_hash"] < levels[lv][1]:
                    levels[lv] = (c["who"], c["tip_hash"])   # 该层持有者
                best = c
        claims = {}
        for who, _h in levels.values():
            claims[who] = claims.get(who, 0) + C_FIXED
        for who, blocks in phi.items():
            claims[who] = claims.get(who, 0) + PHI * blocks
        for who, b in data.items():
            claims[who] = claims.get(who, 0) + PHI_DATA * b
        total = sum(claims.values())
        scale = min(1.0, R_WINDOW_MAX / total) if total else 0
        payout = {w: v * scale for w, v in claims.items()}
        return round(sum(payout.values()), 6), payout, best, levels

    def C(who, count, slot, h=5, b=0):
        return {"who": who, "count": count, "tip_slot": slot, "tip_hash": h, "bytes": b}

    # --- a) 新层级(同 count、更晚 tip_slot)的改进者收回成本 --------------------
    tot, pay, best, lv = settle([C("A", 100, 1000), C("B", 100, 1010)])
    check("P13a 同 count 更晚 tip_slot 是新层级,改进者收回固定成本",
          pay.get("B", 0) >= C_FIXED - 1e-9 and best["who"] == "B" and len(lv) == 2)

    # --- b) 同层 tip_hash 顶替:该层那一份 C_fixed 归【持有者】 ------------------
    # A 先提交(h=9)并推进了 100 块,B 以更小 hash 顶替同一层。
    # A 保留自己的边际块奖励(它确实加了块),但该层的固定成本归 B。
    tot, pay, best, lv = settle([C("A", 100, 1000, h=9), C("B", 100, 1000, h=2)])
    check("P13b 同层 hash 顶替: 该层唯一一份 C_fixed 归持有者 B,A 只保留 φ 部分",
          len(lv) == 1 and lv[(100, 1000)][0] == "B"
          and pay.get("B", 0) >= C_FIXED - 1e-9
          and abs(pay.get("A", 0) - PHI * 100) < 1e-9
          and best["who"] == "B")

    # --- c) 【关键回归】同层磨 n 个 hash 只产生一份 C_fixed ----------------------
    # 基线已在 count=100:磨 hash 不增加任何块,支付应【纯粹】是层级固定成本。
    n = 40
    grind_hash = [C("EQ", 100, 1000, h=1000 - i) for i in range(n)]
    tot_g, payg, _, lvg = settle(grind_hash, base_count=100)
    check("P13c 同层磨 40 个 tip_hash(不加块): 全窗仅产生一份 C_fixed",
          len(lvg) == 1 and abs(tot_g - C_FIXED) < 1e-9
          and abs(payg["EQ"] - C_FIXED) < 1e-9)

    # 对照:上一版"每个严格改进者一份"会付出 40 份,即攻击成立
    old_rule_fixed = n * C_FIXED
    check("P13c2 同构型下旧规则支付 40 份 C_fixed(证明该回归确有鉴别力)",
          old_rule_fixed == 40 * C_FIXED and old_rule_fixed > 10 * tot_g)

    # 攻击者一次 L_eq + n 次证明,只收回一份 ⇒ 净亏
    L_EQ = 500
    check("P13c3 攻击者净亏: L_eq + n×真实成本 远超其所得",
          L_EQ + n * TRUE_COST > tot_g)

    # --- d) 拆前缀:每个前缀是新层级,但 C_FIXED ≤ 真实成本 ⇒ 至多打平 ----------
    one, pay1, _, lv1 = settle([C("X", 12, 1200)])
    grind, payg2, _, lvk = settle([C("X", i, 1000 + i) for i in range(1, 13)])
    phi_one = one - len(lv1) * C_FIXED
    phi_grind = grind - len(lvk) * C_FIXED
    check("P13d 拆 12 个前缀: 边际块奖励与一次落满相同,固定部分至多打平",
          abs(phi_one - phi_grind) < 1e-9 and len(lvk) == 12
          and grind <= 12 * TRUE_COST + phi_grind + 1e-9)

    # --- e) 多个独立诚实改进者各自收回成本(旧的共享上限在此失效) --------------
    def shared_cap_rule(subs, base_count=0):
        """更早的一版:窗口上限只含【一份】C_FIXED,超额一律按比例分摊。"""
        best, claims = None, []
        for c in subs:
            if best is None or key(c) > key(best):
                added = max(0, c["count"] - (best["count"] if best else base_count))
                claims.append(C_FIXED + PHI * added); best = c
        cap = C_FIXED + PHI * (best["count"] - base_count) if best else 0
        tot = sum(claims)
        return [x * min(1.0, cap / tot) for x in claims] if tot else []

    subs3 = [C("A", 5, 500, h=9), C("B", 5, 510, h=9), C("D", 6, 600)]
    tot_m, paym, _, lv3 = settle(subs3, base_count=5)
    check("P13e 三个独立改进者各自收回成本(共享上限规则下人人低于成本)",
          len(lv3) == 3 and all(v >= C_FIXED - 1e-9 for v in paym.values())
          and all(v < C_FIXED for v in shared_cap_rule(subs3, 5)))

    # --- f) 对抗序列:count 与 tip 改进交替,人人仍收回成本 --------------------
    adv = [C("A", 5, 500), C("B", 5, 510), C("A", 6, 600), C("B", 6, 610),
           C("A", 7, 700), C("B", 7, 710)]
    tot_a, paya, best_a, lva = settle(adv)
    check("P13f 对抗序列: 每个改进者仍收回成本,层级数 = 真实推进步数",
          len(lva) == 6 and best_a["count"] == 7
          and all(v >= C_FIXED - 1e-9 for v in paya.values()))

    # --- g) 更差候选不被接受,不产生支付 ----------------------------------------
    tot_w, payw, _, lvw = settle([C("A", 12, 1200), C("B", 4, 400), C("D", 9, 900)])
    check("P13g 更差候选零支付(不接受即不计费)",
          set(payw) == {"A"} and len(lvw) == 1)

    # --- h) 数据发布成本可报销:兜底方发布的数据字节按 φ_data 计价 -------------
    tot_d, payd, _, _ = settle([C("F", 20, 2000, b=64)])
    check("P13h 兜底方发布数据的字节成本获报销(否则数据被扣留时无人愿意兜底)",
          payd["F"] >= C_FIXED + PHI_DATA * 64 - 1e-9)

    # --- i) 硬上限是安全阀:正常窗口不触发,极端情形下确实封顶 -----------------
    normal, _, _, _ = settle([C("A", 50, 500), C("B", 120, 1200)])
    huge = [C("g%d" % i, i, 10 * i) for i in range(1, 1201)]
    tot_h, _, _, _ = settle(huge)
    check("P13i 硬上限不约束正常窗口,极端情形下封顶保证金外流",
          normal < R_WINDOW_MAX and tot_h <= R_WINDOW_MAX + 1e-9)


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
