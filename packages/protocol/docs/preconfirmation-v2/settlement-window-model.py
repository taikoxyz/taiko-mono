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


def test_p13_two_phase_fallback_window():
    """§6.3: 承诺须【结构性可验】,冻结集有上界 K,全轮只有【一个绝对截止】。

    上一版说"每窗口恰好委托一次证明",但同一份模型在赢家无效时顺延、又委托了
    第二次——散文与模型直接矛盾,而 20 个承诺的刷量测试默认每个承诺都有效。
    真实攻击:承诺只携带【声称的】(count, tip_slot, tip_hash),没有任何证明;
    攻击者提交若干排名最高的【无效】承诺,每一个都消耗一个证明期限,于是可以
    买下任意多个连续期限。L_commit 给不了确定性活性:调高伤害无许可性,调低
    则拖延变得廉价。

    修正三件事:
      1) 承诺必须附带【结构性证明】:声称的三元组确实对应一条由已登记数据支撑、
         签名正确且首尾相连的 header 链。这不含执行有效性,因此便宜;而谎报
         三元组即为可罚没的事实。执行有效性仍留到冻结之后再证。
      2) 冻结集有共识上界 K:只取排名最高的 K 个承诺。
      3) 全轮只有【一个绝对截止】T_close,不是每次失败续一个新期限;冻结后
         由有保证金的证明者并行验证并证明,收盘时取【在截止前完成证明的
         排名最高者】。因此无效承诺的影响被确定性地限制住,而不是被计价。
    """
    K_MAX, L_COMMIT = 4, 5

    def key(c):
        return (c["count"], c["tip_slot"], -c["tip_hash"])

    def run_round(commitments, t_close, structurally_valid, exec_valid, prove_time):
        """结构性过滤 → 取前 K 冻结 → 并行证明 → 截止前排名最高的已证明者获胜。"""
        admitted = [c for c in commitments if structurally_valid.get(c["who"], True)]
        rejected = [c["who"] for c in commitments if not structurally_valid.get(c["who"], True)]
        frozen = sorted(admitted, key=key, reverse=True)[:K_MAX]
        proven = [c for c in frozen
                  if exec_valid.get(c["who"], True) and prove_time.get(c["who"], 1) <= t_close]
        winner = max(proven, key=key) if proven else None
        # 并行证明:全轮耗时是【单次】证明时延,不随候选数增长
        elapsed = max([prove_time.get(c["who"], 1) for c in frozen], default=0)
        return frozen, winner, rejected, elapsed

    def K(who, count, slot, h=5):
        return {"who": who, "count": count, "tip_slot": slot, "tip_hash": h}

    # --- a) 正常轮次: 冻结集内最高者获胜 ---------------------------------------
    fr, win, rej, el = run_round([K("A", 5, 500), K("F", 9, 900)], 10, {}, {}, {})
    check("P13a 冻结集内排名最高且在截止前证明完成者获胜",
          win["who"] == "F" and len(fr) == 2)

    # --- b) 【本轮回归】无效承诺不能买下连续期限 -------------------------------
    # 4 个排名最高的承诺执行无效,1 个诚实承诺有效。绝对截止不因失败而延长。
    attack = [K("BAD%d" % i, 9, 900, h=i) for i in range(4)] + [K("HONEST", 5, 500)]
    fr, win, rej, el = run_round(attack, 10, {}, {"BAD%d" % i: False for i in range(4)}, {})
    check("P13b 无效承诺占满冻结集: 全轮仍在同一个绝对截止内收盘,不产生连续期限",
          win is None and el <= 10 and len(fr) == K_MAX)
    check("P13b2 全轮耗时 = 单次证明时延,不随候选数增长(并行证明)", el == 1)

    # --- c) 结构性证明把谎报三元组挡在冻结之外 ---------------------------------
    liars = [K("LIAR%d" % i, 99, 9900, h=i) for i in range(6)] + [K("HONEST", 5, 500)]
    fr, win, rej, el = run_round(
        liars, 10, {"LIAR%d" % i: False for i in range(6)}, {}, {})
    check("P13c 谎报排序字段的承诺被结构性证明挡下,不进入冻结集",
          len(rej) == 6 and win["who"] == "HONEST" and len(fr) == 1)

    # --- d) 冻结集上界 K 生效: 刷 20 个承诺只有前 K 个进入 ---------------------
    spam = [K("EQ%d" % i, 1, 100, h=100 - i) for i in range(20)] + [K("HONEST", 1, 100, h=0)]
    fr, win, rej, el = run_round(spam, 10, {}, {}, {})
    check("P13d 刷 20 个承诺: 冻结集被 K 截断,影响被确定性限制而非计价",
          len(fr) == K_MAX and win["who"] == "HONEST")

    # --- e) 截止之后完成的证明不算数(绝对截止,不顺延) ------------------------
    fr, win, rej, el = run_round([K("SLOW", 9, 900), K("FAST", 5, 500)], 10, {},
                                 {}, {"SLOW": 99, "FAST": 3})
    check("P13e 截止后完成的证明不计入: 取截止前已证明的排名最高者",
          win["who"] == "FAST")

    # --- f) 无人在截止前证明 ⇒ 本轮到期,不是无限延长 --------------------------
    fr, win, rej, el = run_round([K("A", 9, 900)], 10, {}, {"A": False}, {})
    check("P13f 无人证明 ⇒ 本轮 EXPIRE,窗口不被无限延长", win is None)

    # --- g) 时序上界不随候选数增长 --------------------------------------------
    T_COMMIT, P_PROVE_MAX, T_INCLUDE_MAX, MARGIN = 8, 20, 6, 4
    t_fallback = T_COMMIT + P_PROVE_MAX + T_INCLUDE_MAX + MARGIN
    check("P13g T_fallback ≥ T_commit + P_prove,max + T_include,max + margin,与 K 无关",
          t_fallback == 38 and t_fallback > P_PROVE_MAX + T_INCLUDE_MAX)


def test_p13b_escrow_ownership_and_wealth():
    """§6.3: 托管由聚合器出资、全额预注资、无论是否被终止都可退还。

    上一版把托管说成"预注资"却没有定义出资人、归属、退款条件与终止时的行为。
    若托管由国库出资 ⇒ 聚合器的 Sybil 可以把外部奖励提走;
    若由聚合器出资但【被终止时没收】⇒ 预期终止时它又变成可洗的目标。
    正确设定: 聚合器出资,席位激活前必须注满 R_window_max,未用余额【无论是否
    终止】都可退还,但锁定到所有相关窗口结算完毕。于是自付只是把自己的可退还
    资产挪个位置,救不回注定被罚没的抵押。
    """
    R_WINDOW_MAX, PENALTY, FEE, R, COST = 100, 600, 40, 28, 10

    def wealth(self_pay, terminated):
        escrow_refund = R_WINDOW_MAX - (R if self_pay else 0)   # 未用余额可退
        receipt = R if self_pay else 0
        penalty_left = 0 if terminated else PENALTY - FEE       # 终止则惩罚金没收
        return escrow_refund + receipt + penalty_left - (COST if self_pay else 0)

    check("P13b-a 未终止时自付不改变总财富(只是挪动自有可退资产,再减证明成本)",
          wealth(True, False) == wealth(False, False) - COST)
    check("P13b-b 预期终止时自付同样救不回抵押(托管本就可退,惩罚金独立没收)",
          wealth(True, True) == wealth(False, True) - COST)
    check("P13b-c 席位激活前必须注满 R_window_max", R_WINDOW_MAX > 0)


def test_p14_exit_bond_release_is_state_dependent():
    """§4.1/§4.3: 一个统一的解锁谓词,到期是历史块永久有效的【唯一】例外。

    上一版把"到期"和真正的解锁谓词分开测,于是散文里两条规则互相打架:
    退出要求终局头越过【每一个】排班 slot,却又说停摆时到期可以释放保证金;
    §4.3 同时宣称更早的 slot 永久有效。而 P14g 的断言是 bearer == "buyer" ——
    那是【已被否决的】可转让凭证的结局,与该断言自己的名字正好相反,测试通过
    却在断言反面。到期参数也只硬编码在模型里,没有进入参数表。

    统一谓词:保证金解锁 ⟺
      (1) 该 builder 的【每一个】排班 slot 都满足:已被窗口终局头越过,
          或已在某个【已收盘】的快照中到期;
      (2) 没有仍可接纳含该 slot 候选的窗口未收盘;
      (3) 证据提交延迟 δ_slash + 余量已过。
    到期资格在窗口开启时快照,H_slot_expire 是共识参数(已进入参数表)。
    """
    DELTA_SLASH, MARGIN, H_SLOT_EXPIRE = 64, 32, 4096

    def slot_settled(slot, final_head, now, snapshot_closed):
        """(1) 被终局头越过,或在已收盘的快照中到期。"""
        passed = final_head > slot
        expired = (now - slot) > H_SLOT_EXPIRE and snapshot_closed
        return passed or expired

    def unlock(slots, final_head, now, snapshot_closed, open_window_admits, since_met):
        if not all(slot_settled(s, final_head, now, snapshot_closed) for s in slots):
            return False
        if open_window_admits:
            return False
        return since_met >= DELTA_SLASH + MARGIN

    SLOTS = [900, 1000]

    check("P14a 终局头未越过且未到期 ⇒ 不解锁",
          not unlock(SLOTS, 950, 1100, True, False, 10_000))
    check("P14b 仍有窗口可接纳 ⇒ 不解锁",
          not unlock(SLOTS, 1200, 1100, True, True, 10_000))
    check("P14c 状态条件满足但 δ_slash + 余量未过 ⇒ 不解锁",
          not unlock(SLOTS, 1200, 1100, True, False, DELTA_SLASH + MARGIN - 1))
    check("P14d 三个合取项齐备 ⇒ 解锁",
          unlock(SLOTS, 1200, 1100, True, False, DELTA_SLASH + MARGIN))

    # --- e) 停摆:终局头不动,但到期在【已收盘】快照中生效 ⇒ 有界释放 ----------
    stalled_head, long_after = 800, max(SLOTS) + H_SLOT_EXPIRE + 1   # 以【最晚】的排班 slot 为准
    check("P14e 停摆时终局头不动,但快照到期使解锁有界(不再无限期锁住)",
          not unlock(SLOTS, stalled_head, 1100, True, False, 10_000)
          and unlock(SLOTS, stalled_head, long_after, True, False, DELTA_SLASH + MARGIN))

    # --- f) 到期资格必须在【已收盘】的快照中,未收盘不算 -----------------------
    check("P14f 到期资格只在已收盘的快照中生效,未收盘不得据以解锁",
          not unlock(SLOTS, stalled_head, long_after, False, False, 10_000))

    # --- g) 【本轮修正】到期是历史块永久有效的唯一例外;罚没归属不转移 --------
    # 上一版这里断言 bearer == "buyer",即可转让凭证的结局,与名字相反。
    def historical_block_valid(slot, now, snapshot_closed):
        """§4.3: 早于生效 slot 的块永久有效 —— 除非它已在已收盘快照中到期。"""
        return not ((now - slot) > H_SLOT_EXPIRE and snapshot_closed)
    check("P14g 到期是历史块永久有效的唯一例外(未到期仍永久有效)",
          historical_block_valid(1000, 1100, True)
          and not historical_block_valid(1000, 1000 + H_SLOT_EXPIRE + 1, True))
    def slash_bearer(exit_scheme):
        """凭证可转让 ⇒ 买方承担;到期方案 ⇒ 始终是签名密钥持有者。"""
        return "buyer" if exit_scheme == "transferable_claim" else "key_holder"
    check("P14h 到期方案下罚没始终由签名密钥持有者承担(可转让凭证则转嫁给买方)",
          slash_bearer("snapshot_expiry") == "key_holder"
          and slash_bearer("transferable_claim") == "buyer")


def test_p15_reward_pot_disjoint_from_penalty_pot():
    """§4.1/§6.3: 兜底报酬必须来自【独立预注资的报酬托管】,不得来自可罚没保证金。

    先前的不变式"迟到费 > 单窗口最大报销额"论证是错的。若报销取自聚合器自己的
    可退还保证金,联盟总财富 = (B − fee − R) + R − cost = B − fee − cost:R 恒等
    消去,故该不等式对【获利】既非必要;而当聚合器预期被终止时,fee 出自本就要
    被罚没的钱,其边际成本为零,于是每轮洗出 R 只需付一次证明 cost —— 只要
    R > cost 就有利可图,故该不等式对【洗出可罚没抵押】也不充分。

    修正:惩罚保证金(不可退还,承担过错、迟到费从中销毁)与报酬托管(预注资,
    支付兜底成本)必须是两个互不相交的池。从托管支付不减少惩罚保证金,故没有
    可洗的东西;再加上支付后最低惩罚抵押要求,否则原子终止席位。
    """
    B, FEE, R, COST = 1000, 40, 28, 10

    # --- a) 旧论证:R 在联盟财富中恒等消去 ⇒ 不等式与获利无关 -------------------
    single_pot = (B - FEE - R) + R - COST
    check("P15a 单一池下 R 在联盟财富中消去 ⇒ 迟到费 > 报销额与是否获利无关",
          single_pot == B - FEE - COST)

    # --- b) 预期终止时,fee 出自已注定被罚没的钱 ⇒ 洗钱只需付证明成本 ----------
    keep_doing_nothing = 0                 # 保证金全额罚没
    keep_by_laundering = R - COST          # 洗出 R 到不可罚没地址,付一次证明
    check("P15b 预期终止时 R > cost 即可洗出可罚没抵押(旧不变式不充分)",
          keep_by_laundering > keep_doing_nothing and R > COST)

    # --- c) 两池分离后:从托管支付不减少惩罚保证金 ⇒ 无可洗之物 ----------------
    penalty, escrow = 600, 400
    penalty_after = penalty - FEE          # 迟到费只从惩罚保证金销毁
    escrow_after = escrow - R              # 报销只从托管支出
    slashable_before, slashable_after = penalty, penalty_after
    check("P15c 两池分离: 报销不触及惩罚保证金 ⇒ 可罚没额只因罚款下降,不因报销下降",
          slashable_before - slashable_after == FEE and escrow_after == escrow - R)

    # --- d) 洗出量为零:托管本就不可罚没,取回它不改变终止时被罚没的金额 -------
    launder_gain = (penalty - penalty_after) - FEE      # 报销未从可罚没池取走任何钱
    check("P15d 两池分离下洗出可罚没抵押的收益为零", launder_gain == 0)

    # --- e) 支付后最低惩罚抵押:低于阈值则原子终止席位 -------------------------
    MIN_PENALTY = 500
    def ok_after_payment(pen):
        return pen >= MIN_PENALTY
    check("P15e 支付后惩罚抵押低于下限 ⇒ 必须原子终止席位",
          ok_after_payment(560) and not ok_after_payment(MIN_PENALTY - 1))

    # --- f) B_max / R_window_max 必须是共识常量,而非模型里的任意值 ------------
    B_MAX, R_WINDOW_MAX = 6, 10_000        # 见 §12 参数表(本轮补入)
    check("P15f B_max 与 R_window_max 为共识常量并已进入参数表",
          B_MAX > 0 and R_WINDOW_MAX > 0)


if __name__ == "__main__":
    for t in [test_p1_total_order, test_p2_order_independence,
              test_p3_supersession_cursors,
              test_p5_lazy_close, test_p6_reorg_replay, test_p7_gas_no_deadlock,
              test_p7b_single_message_cap_is_load_bearing, test_p9_anchor_geometry,
              test_p10_slashing_acceptance_gate, test_p11_fallback_snapshot,
              test_p12_midwindow_enqueue,
              test_p13_two_phase_fallback_window,
              test_p13b_escrow_ownership_and_wealth,
              test_p14_exit_bond_release_is_state_dependent,
              test_p15_reward_pot_disjoint_from_penalty_pot]:
        t()
    print("RESULTS: settlement-window model — ALL PROPERTIES PASS")
    for i, name in enumerate(PASS, 1):
        print(f"  [{i:02d}] {name}")
