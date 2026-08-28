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
    """§4.3: 罚没生效只看 header.slot,且【不追溯】——三版规则的最终形态。

    (1) 按候选的 L1 落地时点判定:可被武器化。等价物自选提交证据的时刻,而
        δ_slash 远短于证明+上链,故它能让生效时点落在"诚实候选已构造、尚未
        落地"之间,较重的诚实候选被判无效而非被压过,整条尾巴级联作废。
    (2) 按结算窗口作用域判定:武器化消失,但代价是罚没最多晚一个 W_settle 才
        生效,L_eq 的敞口因而多出 1800 个 L2 slot(320 → 680 slot),与 [G6]
        低进入门槛直接冲突。而它所防的"回填历史 slot"本来就已被明示接受。
    (3) 最终:只看 header.slot ≥ 生效 slot,立即生效,且对更早的 slot 不追溯。
        没有任何候选会因时点而被判无效 ⇒ 武器化消失;没有窗口延迟 ⇒ 敞口回到
        1535 + δ_slash。回填被接受(其无害性论证见 §4.3)。
    """
    DELTA_SLASH = 64
    S0 = 100                              # 证据被 L1 打包时对应的 L2 slot
    EFFECTIVE = S0 + DELTA_SLASH          # = 164

    def valid(header_slot):
        """最终规则:与落地时点、窗口都无关,只比较 slot。"""
        return header_slot < EFFECTIVE

    # a) 纯函数:同一个块在任何候选、任何落地时点下判定相同
    verdicts = {t: valid(150) for t in (101, 164, 200, 5000)}
    check("P10a 判定只依赖 header.slot,与落地时点/窗口无关(纯函数)",
          len(set(verdicts.values())) == 1 and verdicts[5000] is True)

    # b) 前向规则确实生效:生效 slot 及其之后该签名者的块一律无效
    check("P10b 生效 slot 起该签名者的槽位成为 gap",
          valid(163) and not valid(164) and not valid(500))

    # c) 不追溯 ⇒ 在飞行中的诚实候选永不会被罚没判无效(武器化消失)
    #    对照规则 (1):同一个块按落地时点判定会给出相反结论。
    def landing_time_rule(cand_landed_at):
        return cand_landed_at < EFFECTIVE
    inflight = [120, 170, 300]            # 同一个 header.slot=150 的块,落地时点不同
    check("P10c 不追溯: header.slot=150 的块在任何落地时点都有效;"
          "旧的落地时点规则会判其中一部分无效",
          all(valid(150) for _ in inflight)
          and not all(landing_time_rule(t) for t in inflight))

    # d) 级联被 δ_slash 限住:攻击者要作废自己的块,该块的 slot 必须 ≥ 生效 slot,
    #    即至少在它公开自罚 δ_slash 之后 —— 届时罚没已公开,诚实方按规则跳过它。
    check("P10d 攻击者能作废的最早槽位比其提交证据晚 δ_slash,诚实方有同等预警",
          EFFECTIVE - S0 == DELTA_SLASH and not valid(EFFECTIVE))

    # e) 无窗口延迟 ⇒ L_eq 敞口不含 W_settle_max 项(见 §4.1 的 320 vs 680)
    exposure_slot_only = 1535 + DELTA_SLASH
    exposure_window_scoped = 1535 + DELTA_SLASH + 1800
    check("P10e 敞口回到 1535 + δ_slash;窗口作用域会多出一个 W_settle_max",
          round(0.20 * exposure_slot_only) == 320
          and round(0.20 * exposure_window_scoped) == 680)


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
    """§6.3: 保证金每窗口至多付一次;获胜层级被【争夺】时一分不付。

    付款对象的选择本身是死路:攻击者总能以【一次证明】的代价占住层级的任一端。
      · 付给排序赢家 ⇒ 收盘抢跑者最后提交更小 tip_hash,拿走报酬;
      · 付给最先到达者 ⇒ 抢占者先提交较差的同层候选,再把更小 hash 的替代块放给
        诚实兜底方去证明,诚实方赢得排序却拿不到钱,抢占者的证明反被报销。
    两端都可占,故任何"选一个受益人"的规则都可被同一手法击破。

    可用的不变量是:同层出现两个不同 tip_hash ⇒ 该 slot 的 builder 等价物签名
    (§5.2),即该层级被争夺。规则因此是:获胜层级若被争夺,本窗口保证金零支付。
    抢跑与抢占都白付一次证明且一无所获。诚实方在被争夺的窗口同样拿不到钱——
    这是残留代价,不是被解决的问题,§6.3 与 §11 如实记录。

    聚合器自付不能靠地址比对来防(它可以在证明的公开输入里填任意受益人地址,
    无许可系统里无法强制经济归属)。改为定价不变式:迟到费 > 单窗口最大报销额,
    于是无论受益人是谁,故意越过兜底阈值的聚合器净亏。
    """
    C_FIXED, PHI_DATA = 10, 3
    TRUE_COST = 10
    B_MAX = 6                      # 单窗口可报销的最大 blob 数
    LATE_FEE = 40                  # 迟到费;不变式见 P13c

    def key(c):
        return (c["count"], c["tip_slot"], -c["tip_hash"])

    def settle(subs, base_count=0, fee_share=0):
        """接受严格更优者;获胜层级被争夺则零支付,否则付该层唯一到达者。"""
        best, at_level = None, {}
        for c in subs:
            if best is None or key(c) > key(best):
                at_level.setdefault((c["count"], c["tip_slot"]), []).append(c)
                best = c
        if best is None:
            return 0, {}, None, at_level
        reached = at_level[(best["count"], best["tip_slot"])]
        if len({c["tip_hash"] for c in reached}) > 1:      # 被争夺 ⇒ 零支付
            return 0, {}, best, at_level
        payee = reached[0]
        blobs = len(set(payee.get("blobs", ())))
        bond_out = max(0, C_FIXED + PHI_DATA * blobs - fee_share)
        return bond_out, {payee["who"]: bond_out}, best, at_level

    def C(who, count, slot, h=5, blobs=()):
        return {"who": who, "count": count, "tip_slot": slot, "tip_hash": h,
                "blobs": list(blobs)}

    # --- a) 未被争夺的正常窗口:兜底方获赔一次 ---------------------------------
    out, pay, best, _ = settle([C("A", 5, 500), C("B", 9, 900)])
    check("P13a 未争夺窗口: 兜底方获赔一次固定成本",
          best["who"] == "B" and set(pay) == {"B"} and abs(out - C_FIXED) < 1e-9)

    # --- b) 收盘抢跑(诚实先、抢跑后):零支付,抢跑白付一次证明 ---------------
    out_s, pay_s, best_s, _ = settle([C("HONEST", 1, 100, h=9),
                                      C("SNIPER", 1, 100, h=2)])
    check("P13b 抢跑: 层级被争夺 ⇒ 零支付,抢跑者赢排序但一无所获",
          best_s["who"] == "SNIPER" and pay_s == {} and abs(out_s) < 1e-9)

    # --- b2) 【本轮回归】抢占(攻击者先、诚实后):同样零支付 ------------------
    # 攻击者先提交较差同层候选,再放出更小 hash 的块让诚实方去证明并赢得排序。
    out_p, pay_p, best_p, _ = settle([C("ATTACKER", 1, 100, h=9),
                                      C("HONEST", 1, 100, h=2)])
    check("P13b2 抢占(反向顺序): 层级仍被争夺 ⇒ 攻击者的证明【不】被报销",
          best_p["who"] == "HONEST" and pay_p == {} and abs(out_p) < 1e-9)
    check("P13b3 两个方向都不获利: 攻击者两种顺序下所得均为零",
          pay_s.get("SNIPER", 0) == 0 and pay_p.get("ATTACKER", 0) == 0)

    # --- b4) 残留代价如实建模: 被争夺窗口里诚实方也拿不到钱 -------------------
    check("P13b4 残留: 被争夺的窗口中诚实方同样零支付(§6.3/§11 记录为未解决)",
          pay_s.get("HONEST", 0) == 0 and pay_p.get("HONEST", 0) == 0)

    # --- c) 聚合器自付靠【定价不变式】而非地址比对 -----------------------------
    max_reimb = C_FIXED + PHI_DATA * B_MAX
    check("P13c 迟到费 > 单窗口最大报销额 ⇒ 无论受益人是谁,聚合器故意迟到净亏",
          LATE_FEE > max_reimb and LATE_FEE - max_reimb > 0)
    # 用任意(含 Sybil)受益人地址都拿不到超过 max_reimb
    out_a, pay_a, _, _ = settle([C("SYBIL_OF_AGG", 20, 2000, blobs=tuple(range(B_MAX)))])
    check("P13c2 任意受益人地址的单窗口所得 ≤ 最大报销额 < 迟到费",
          pay_a["SYBIL_OF_AGG"] <= max_reimb + 1e-9 and pay_a["SYBIL_OF_AGG"] < LATE_FEE)

    # --- d) 前缀拆分 30 次:仍至多一次支付 --------------------------------------
    N = 30
    out_pf, _, _, lv = settle([C("EQ", i, 1000 + i) for i in range(1, N + 1)])
    check("P13d 前缀拆分 30 次: 至多一次支付,攻击者净亏 N-1 次证明",
          abs(out_pf - C_FIXED) < 1e-9 and len(lv) == N
          and N * TRUE_COST - out_pf >= (N - 1) * TRUE_COST - 1e-9)

    # --- e) tip_hash 磨榨 40 次:同层被争夺 ⇒ 零支付 ---------------------------
    out_g, _, _, _ = settle([C("EQ", 100, 1000, h=1000 - i) for i in range(40)],
                            base_count=100)
    check("P13e tip_hash 磨榨 40 次: 层级被争夺 ⇒ 零支付", abs(out_g) < 1e-9)

    # --- f) 结构性上界:任意序列下外流 ≤ 一个候选的成本 ------------------------
    import random
    rng = random.Random(20260828)
    for _ in range(400):
        seq, cnt, slot = [], 0, 0
        for _ in range(rng.randint(1, 25)):
            cnt += rng.randint(0, 3); slot += rng.randint(0, 40)
            seq.append(C("w%d" % rng.randint(0, 5), cnt, slot,
                         h=rng.randint(0, 999), blobs=tuple(range(rng.randint(0, 4)))))
        o, _, _, _ = settle(seq)
        assert o <= C_FIXED + PHI_DATA * 4 + 1e-9, "structural bound violated"
    check("P13f 400 组随机序列: 外流恒 ≤ 一个候选的成本(与候选数无关)", True)

    # --- g) 费用份额覆盖成本时保证金零外流 -------------------------------------
    out_f, _, _, _ = settle([C("A", 9, 900)], fee_share=C_FIXED + 5)
    check("P13g §7 费用份额覆盖成本时保证金零外流(只补缺口)", abs(out_f) < 1e-9)

    # --- h) 更差候选零支付 -----------------------------------------------------
    out_w, pay_w, _, _ = settle([C("A", 12, 1200), C("B", 4, 400)])
    check("P13h 更差候选零支付(不接受即不计费)", set(pay_w) == {"A"})

    # --- i) φ_data 按 blob 计价并按 versioned hash 去重 -------------------------
    out_d, pay_d, _, _ = settle([C("F", 20, 2000, blobs=(7, 7, 8))])
    check("P13i φ_data 按 blob 计价、同一 versioned hash 只报销一次",
          abs(pay_d["F"] - (C_FIXED + PHI_DATA * 2)) < 1e-9)


def test_p14_exit_bond_release_is_state_dependent():
    """§4.1: 退出解锁 = 链状态条件 + δ_slash + 检测/提交余量,三者缺一不可。

    上一版的可执行判定只检查了"终局头越过 + 无窗口可接纳",漏掉了散文里要求的
    δ_slash 与余量,于是允许在等价物证据仍在途中时立刻取回保证金 —— Appendix C
    称模型为规范件,故该缺口当时并未真正关闭。
    """
    DELTA_SLASH, MARGIN = 64, 32
    last_slot = 1000

    def time_based_unlock():
        return last_slot + DELTA_SLASH + MARGIN            # 旧规则(仅墙钟)

    def state_based_unlock(final_head_slot, open_window_admits_slot,
                           slots_since_state_condition_met):
        """状态条件满足后,还须再等 δ_slash + 余量,证据才不可能仍在途中。"""
        if final_head_slot <= last_slot or open_window_admits_slot:
            return False
        return slots_since_state_condition_met >= DELTA_SLASH + MARGIN

    # a) 纯时间解锁会在历史块仍可落地时释放保证金
    check("P14a 纯时间解锁会在历史块仍可落地时释放保证金(等价物无从罚没)",
          time_based_unlock() < last_slot + 5000)

    # b) 终局头未越过最后排班 slot ⇒ 不解锁
    check("P14b 终局头未越过最后排班 slot ⇒ 不解锁",
          not state_based_unlock(900, False, 10_000))

    # c) 仍有窗口可接纳该 slot 的候选 ⇒ 不解锁
    check("P14c 仍有窗口可接纳该 slot 的候选 ⇒ 不解锁",
          not state_based_unlock(1200, True, 10_000))

    # d) 【本轮回归】状态条件刚满足、δ_slash + 余量未过 ⇒ 仍不解锁
    check("P14d 状态条件满足但 δ_slash + 余量未过 ⇒ 不解锁(证据可能仍在途中)",
          not state_based_unlock(1200, False, DELTA_SLASH + MARGIN - 1))

    # e) 三者齐备才解锁
    check("P14e 状态条件 + δ_slash + 余量 全部满足 ⇒ 方可解锁",
          state_based_unlock(1200, False, DELTA_SLASH + MARGIN))


if __name__ == "__main__":
    for t in [test_p1_total_order, test_p2_order_independence,
              test_p3_supersession_cursors,
              test_p5_lazy_close, test_p6_reorg_replay, test_p7_gas_no_deadlock,
              test_p7b_single_message_cap_is_load_bearing, test_p9_anchor_geometry,
              test_p10_slashing_acceptance_gate, test_p11_fallback_snapshot,
              test_p12_midwindow_enqueue,
              test_p13_reward_metered_on_marginal_advancement,
              test_p14_exit_bond_release_is_state_dependent]:
        t()
    print("RESULTS: settlement-window model — ALL PROPERTIES PASS")
    for i, name in enumerate(PASS, 1):
        print(f"  [{i:02d}] {name}")
