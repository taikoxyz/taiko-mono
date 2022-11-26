import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st
from enum import Enum
from typing import NamedTuple
from plots import plot
from present import Config, Present
from presents.p0 import present as p0
from presents.cbvp1 import present as cbvp1
from presents.cbvp2 import present as cbvp2
from presents.vbcp1 import present as vbcp1
from presents.vbcp2 import present as vbcp2
from presents.vbvps1 import present as vbvps1
from presents.vbvps2 import present as vbvps2

# from presents.p7 import present as p7
# from presents.p8 import present as p8
# from presents.p9 import present as p9
# from presents.p10 import present as p10
# from presents.p11 import present as p11

DAY = 24 * 3600
K_FEE_GRACE_PERIOD = 125
K_FEE_MAX_PERIOD = 375
K_BLOCK_TIME_CAP = 48  # 48 seconds
K_PROOF_TIME_CAP = 3600 * 1.5  # 1.5 hour


class Status(Enum):
    PENDING = 1
    PROVEN = 2
    VERIFIED = 3


class Block(NamedTuple):
    status: Status
    fee: int
    proposed_at: int
    proven_at: int


def get_day(config):
    day = int(env.now() / DAY)
    if day >= len(config.timing):
        day = len(config.timing) - 1
    return day


def get_block_time_avg_second(config):
    return config.timing[get_day(config)].block_time_avg_second


def get_proof_time_avg_second(config):
    return config.timing[get_day(config)].proof_time_avg_minute * 60


def moving_average(ma, v, maf):
    if ma == 0:
        return v
    else:
        _ma = (ma * (maf - 1) + v) * 1.0 / maf
        if _ma > 0:
            return _ma
        else:
            return ma


class Protocol(sim.Component):
    def setup(self, config):
        self.config = config
        self.fee_base = config.fee_base
        self.last_proposed_at = env.now()
        self.last_VERIFIED_id = 0
        self.tko_supply = 0
        self.avg_block_time = 0
        self.avg_proof_time = 0

        genesis = Block(
            status=Status.VERIFIED,
            fee=0,
            proposed_at=env.now(),
            proven_at=env.now(),
        )
        self.blocks = [genesis]

        # monitors
        self.m_pending_count = sim.Monitor("m_pending_count", level=True)
        self.m_fee_base = sim.Monitor(
            "m_fee_base", level=True, initial_tally=self.fee_base
        )
        self.m_block_fee = sim.Monitor("m_block_fee", level=True)
        self.m_proof_reward = sim.Monitor("m_proof_reward", level=True)
        self.m_tko_supply = sim.Monitor("m_tko_supply", level=True)
        self.m_block_time = sim.Monitor("m_block_time", level=True)
        self.m_proof_time = sim.Monitor("m_proof_time", level=True)

    def get_time_adjusted_fee(self, is_proposal, t_now, t_last, t_avg, t_cap):
        #  if (tAvg == 0) {
        #      return s.feeBase;
        #  }
        #  uint256 _tAvg = tAvg > tCap ? tCap : tAvg;
        #  uint256 tGrace = (LibConstants.K_FEE_GRACE_PERIOD * _tAvg) / 100;
        #  uint256 tMax = (LibConstants.K_FEE_MAX_PERIOD * _tAvg) / 100;
        #  uint256 a = tLast + tGrace;
        #  uint256 b = tNow > a ? tNow - a : 0;
        #  uint256 tRel = (b.min(tMax) * 10000) / tMax; // [0 - 10000]
        #  uint256 alpha = 10000 +
        #      ((LibConstants.K_REWARD_MULTIPLIER - 100) * tRel) /
        #      100;
        #  if (isProposal) {
        #      return (s.feeBase * 10000) / alpha; // fee
        #  } else {
        #      return (s.feeBase * alpha) / 10000; // reward
        #  }

        if t_avg == 0:
            return self.fee_base

        if t_avg > t_cap:
            _avg = t_cap
        else:
            _avg = t_avg

        t_grace = K_FEE_GRACE_PERIOD * _avg / 100.0
        t_max = K_FEE_MAX_PERIOD * _avg / 100.0
        a = t_last + t_grace

        if t_now > a:
            b = t_now - a
        else:
            b = 0

        if b > t_max:
            b = t_max

        t_rel = 10000 * b / t_max

        alpha = 10000 + (self.config.reward_multiplier - 1) * t_rel

        if is_proposal:
            return self.fee_base * 10000 / alpha
        else:
            return self.fee_base * alpha / 10000

    def get_slots_adjusted_fee(self, is_proposal, fee):
        # uint256 m = LibConstants.K_MAX_NUM_BLOCKS -
        #     1 +
        #     LibConstants.K_FEE_PREMIUM_LAMDA;
        # uint256 n = s.nextBlockId - s.latestVERIFIEDId - 1;
        # uint256 k = isProposal ? m - n - 1 : m - n + 1;
        # return (fee * (m - 1) * m) / (m - n) / k;

        m = self.config.max_blocks - 1 + self.config.lamda
        n = self.num_pending()
        if is_proposal:  # fee
            k = m - n - 1
        else:  # reward
            k = m - n + 1
        return fee * (m - 1) * m / (m - n) / k

    def get_block_fee(self):
        fee = self.get_time_adjusted_fee(
            True,
            env.now(),
            self.last_proposed_at,
            self.avg_block_time,
            K_BLOCK_TIME_CAP,
        )

        premium_fee = self.get_slots_adjusted_fee(True, fee)
        # bootstrap discount not simulated
        return (fee, premium_fee)

    def get_proof_reward(self, proven_at, proposed_at):
        reward = self.get_time_adjusted_fee(
            False, proven_at, proposed_at, self.avg_proof_time, K_PROOF_TIME_CAP
        )
        premium_reward = self.get_slots_adjusted_fee(False, reward)
        return (reward, premium_reward)

    def print_me(self, st):
        st.markdown("-----")
        st.markdown("##### Protocol state")
        st.write("last_VERIFIED_id = {}".format(self.last_VERIFIED_id))
        st.write("num_blocks = {}".format(self.num_pending()))
        st.write("fee_base = {}".format(self.fee_base))
        st.write("tko_supply = {}".format(self.tko_supply))

    def num_pending(self):
        return len(self.blocks) - self.last_VERIFIED_id - 1

    def can_propose(self):
        return self.num_pending() < self.config.max_blocks

    def propose_block(self):
        if env.now() == 0 or not self.can_propose():
            return

        block_time = env.now() - self.last_proposed_at

        (fee, premium_fee) = self.get_block_fee()

        self.fee_base = moving_average(self.fee_base, fee, self.config.fee_maf)
        self.avg_block_time = moving_average(
            self.avg_block_time,
            block_time,
            self.config.time_avg_maf,
        )
        self.last_proposed_at = env.now()
        self.tko_supply -= premium_fee

        block = Block(
            status=Status.PENDING,
            fee=premium_fee,
            proposed_at=env.now(),
            proven_at=0,
        )
        self.blocks.append(block)

        Prover(protocol=self, config=self.config, blockId=len(self.blocks) - 1)
        self.verify_block()

        self.m_fee_base.tally(self.fee_base)
        self.m_block_fee.tally(premium_fee)
        self.m_tko_supply.tally(self.tko_supply)
        self.m_block_time.tally(block_time)
        self.m_pending_count.tally(self.num_pending())

    def can_prove(self, id):
        return (
            id > self.last_VERIFIED_id
            and len(self.blocks) > id
            and self.blocks[id].status == Status.PENDING
        )

    def prove_block(self, id):
        if self.can_prove(id):
            self.blocks[id] = self.blocks[id]._replace(
                status=Status.PROVEN, proven_at=env.now()
            )
            self.verify_block()

    def can_verify(self):
        return (
            len(self.blocks) > self.last_VERIFIED_id + 1
            and self.blocks[self.last_VERIFIED_id + 1].status == Status.PROVEN
            and env.now()
            > self.blocks[self.last_VERIFIED_id + 1].proven_at + self.avg_proof_time
        )

    def verify_block(self):
        for i in range(0, 5):
            if self.can_verify():

                k = self.last_VERIFIED_id + 1

                self.blocks[k] = self.blocks[k]._replace(status=Status.VERIFIED)

                proof_time = self.blocks[k].proven_at - self.blocks[k].proposed_at

                (reward, premium_reward) = self.get_proof_reward(
                    self.blocks[k].proven_at, self.blocks[k].proposed_at
                )

                self.fee_base = moving_average(
                    self.fee_base,
                    reward,
                    self.config.fee_maf,
                )

                self.avg_proof_time = moving_average(
                    self.avg_proof_time,
                    proof_time,
                    self.config.time_avg_maf,
                )

                self.tko_supply += premium_reward
                self.m_fee_base.tally(self.fee_base)
                self.m_proof_reward.tally(premium_reward)
                self.m_tko_supply.tally(self.tko_supply)
                self.m_proof_time.tally(proof_time)

                self.last_VERIFIED_id = k
            else:
                break

        self.m_pending_count.tally(self.num_pending())


class Prover(sim.Component):
    def setup(self, protocol, config, blockId):
        self.protocol = protocol
        self.config = config
        self.blockId = blockId

    def process(self):
        _proof_time_avg_second = get_proof_time_avg_second(self.config)
        yield self.hold(
            sim.Bounded(
                sim.Normal(
                    _proof_time_avg_second,
                    _proof_time_avg_second * self.config.proof_time_sd_pctg / 100,
                ),
                lowerbound=1,
            ).sample()
        )
        self.protocol.prove_block(self.blockId)


class Proposer(sim.Component):
    def setup(self, protocol):
        self.protocol = protocol
        self.config = protocol.config

    def process(self):
        while True:
            if not self.protocol.can_propose():
                yield self.hold(1)
            else:
                self.protocol.propose_block()
                _block_time_avg_second = get_block_time_avg_second(self.config)
                yield self.hold(
                    sim.Bounded(
                        sim.Normal(
                            _block_time_avg_second,
                            _block_time_avg_second
                            * self.config.block_time_sd_pctg
                            / 100,
                        ),
                        lowerbound=1,
                    ).sample()
                )


def simulate(config, days):
    st.markdown("-----")
    st.markdown("##### Block & proof time and deviation settings")
    st.caption("[block_time (seconds), proof_time (minutes)]")
    time_str = ""
    for t in config.timing:
        time_str += str(t._asdict().values())
    st.write(time_str.replace("dict_values", "  ☀️").replace("(", "").replace(")", ""))

    st.markdown("-----")
    st.markdown("##### You can change these settings")
    cols = st.columns([1, 1, 1, 1])
    inputs = {}
    i = 0
    for (k, v) in config._asdict().items():
        if k != "timing":
            inputs[k] = cols[i % 4].number_input(k, value=v)
            i += 1

    st.markdown("-----")
    if st.button("Simulate {} days".format(days), key="run"):
        actual_config = Config(timing=config.timing, **inputs)

        protocol = Protocol(config=actual_config)
        proposer = Proposer(protocol=protocol)

        env.run(till=days * DAY)

        st.markdown("-----")
        st.markdown("##### Block/Proof Time")
        plot(days, [(protocol.m_block_time, "block time")], color="tab:blue")
        plot(days, [(protocol.m_proof_time, "proof time")], color="tab:blue")

        st.markdown("-----")
        st.markdown("##### Result")
        plot(days, [(protocol.m_pending_count, "num pending blocks")])
        plot(days, [(protocol.m_fee_base, "fee_base")])
        plot(days, [(protocol.m_block_fee, "block fee")], color="tab:green")
        plot(days, [(protocol.m_proof_reward, "proof reward")])

        plot(days, [(protocol.m_tko_supply, "tko supply")], color="tab:red")

        protocol.print_me(st)


if __name__ == "__main__":
    env = sim.Environment(trace=False)
    st.title("Taiko Block Fee/Reward Simulation")

    presents = [p0, cbvp1, cbvp2, vbcp1, vbcp2, vbvps1, vbvps2]
    st.markdown("## Configs")
    selected = st.radio(
        "Please choose one of the following predefined configs:",
        range(0, len(presents)),
        format_func=lambda x: presents[x].title,
    )
    present = presents[selected]
    st.markdown("-----")
    st.markdown("##### Description")
    st.markdown(present.desc)
    simulate(present.config, present.days)
