import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st
from enum import Enum
from typing import NamedTuple
from plots import plot
from present import Config, Present
from presents.p0 import present as p0
from presents.p1 import present as p1
from presents.p2 import present as p2
from presents.p3 import present as p3
from presents.p4 import present as p4
from presents.p5 import present as p5
from presents.p6 import present as p6
from presents.p7 import present as p7
from presents.p8 import present as p8
from presents.p9 import present as p9
from presents.p10 import present as p10
from presents.p11 import present as p11

DAY = 24 * 3600


class Status(Enum):
    PENDING = 1
    PROVEN = 2
    FINALIZED = 3


class Block(NamedTuple):
    status: Status
    fee: int
    proposed_at: int
    proven_at: int


def get_block_fee(base_fee, min_ratio, avg_block_time, block_time):
    if avg_block_time == 0:
        return base_fee

    a = avg_block_time * 1.5
    if block_time <= a:
        return base_fee

    b = avg_block_time * 3
    m = base_fee * min_ratio

    if block_time >= b:
        return m

    return (base_fee - m) * (b - block_time) / (b - a) + m


def get_proof_reward(base_fee, max_ratio, avg_proof_time, proof_time):
    if avg_proof_time == 0:
        return base_fee

    a = avg_proof_time * 1.5
    if proof_time <= a:
        return base_fee

    b = avg_proof_time * 3
    n = base_fee * max_ratio

    if proof_time >= b:
        return n

    return (n - base_fee) * (proof_time - a) / (b - a) + n


def calc_bootstrap_reward(
    prover_reward_bootstrap, prover_reward_bootstrap_day, avg_block_time
):
    if prover_reward_bootstrap == 0:
        return 0
    s = prover_reward_bootstrap * 1.0
    t = prover_reward_bootstrap_day * 24 * 3600
    b = avg_block_time
    if env.now() >= t:
        return 0
    else:
        return 2 * s * b * (t - env.now() + b / 2) / t / t


def get_day(config):
    day = int(env.now() / DAY)
    if day >= len(config.timing):
        day = len(config.timing) - 1
    return day


def get_block_time_avg_second(config):
    return config.timing[get_day(config)].block_time_avg_second


def get_block_time_sd_pctg(config):
    return config.timing[get_day(config)].block_time_sd_pctg


def get_proof_time_avg_second(config):
    return config.timing[get_day(config)].proof_time_avg_minute * 60


def get_proof_time_sd_pctg(config):
    return config.timing[get_day(config)].proof_time_sd_pctg


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
        self.base_fee = config.base_fee
        self.phi = (config.max_blocks + self.config.lamda) * (
            config.max_blocks + self.config.lamda - 1
        )
        self.last_proposed_at = env.now()
        self.last_finalized_id = 0
        self.supply_change = 0
        self.prover_bootstrap_reward_total = 0

        self.avg_block_time = 0
        self.avg_proof_time = 0

        genesis = Block(
            status=Status.FINALIZED,
            fee=0,
            proposed_at=env.now(),
            proven_at=env.now(),
        )
        self.blocks = [genesis]

        # monitors
        self.m_pending_count = sim.Monitor("m_pending_count", level=True)
        self.m_base_fee = sim.Monitor(
            "m_base_fee", level=True, initial_tally=self.base_fee
        )
        self.m_premium_fee = sim.Monitor("m_premium_fee", level=True)
        self.m_premium_reward = sim.Monitor("m_premium_reward", level=True)
        self.m_supply_change = sim.Monitor("m_supply_change", level=True)
        self.m_block_time = sim.Monitor("m_block_time", level=True)
        self.m_proof_time = sim.Monitor("m_proof_time", level=True)
        self.m_prover_bootstrap_reward = sim.Monitor(
            "m_prover_bootstrap_reward", level=True
        )

    def apply_oversell_premium(self, fee, release_one_slot):
        p = self.config.max_blocks - self.num_pending() + self.config.lamda
        if release_one_slot:
            q = p + 1
        else:
            q = p - 1
        return fee * self.phi / p / q

    def get_block_fee(self, min_ratio, block_time):
        fee = get_block_fee(self.base_fee, min_ratio, self.avg_block_time, block_time)
        premium_fee = self.apply_oversell_premium(fee, False)
        return (fee, premium_fee)

    def get_proof_reward(self, max_ratio, proof_time):
        reward = get_proof_reward(
            self.base_fee, max_ratio, self.avg_proof_time, proof_time
        )
        premium_reward = (
            self.apply_oversell_premium(reward, True)
            * (10000.0 - self.config.prover_reward_burn_points)
            / 10000
        )
        return (reward, premium_reward)

    def print(self, st):
        st.markdown("-----")
        st.markdown("##### Protocol state")
        st.write("lamda = {}".format(self.config.lamda))
        st.write("last_finalized_id = {}".format(self.last_finalized_id))
        st.write("num_blocks = {}".format(len(self.blocks)))
        st.write("base_fee = {}".format(self.base_fee))
        st.write("supply_change = {}".format(self.supply_change))
        st.write(
            "prover_bootstrap_reward_total = {}".format(
                self.prover_bootstrap_reward_total
            )
        )

        if self.config.prover_reward_bootstrap > 0:
            st.write(
                "prover_bootstrap_reward_total/config.prover_reward_bootstrap = {}".format(
                    self.prover_bootstrap_reward_total
                    * 1.0
                    / self.config.prover_reward_bootstrap
                )
            )

    def num_pending(self):
        return len(self.blocks) - self.last_finalized_id - 1

    def can_propose(self):
        return self.num_pending() <= self.config.max_blocks

    def propose_block(self):
        if self.can_propose():
            block_time = env.now() - self.last_proposed_at

            (fee, premium_fee) = self.get_block_fee(
                self.config.block_fee_min_ratio, block_time
            )

            self.last_proposed_at = env.now()
            self.avg_block_time = moving_average(
                self.avg_block_time,
                block_time,
                self.config.block_and_proof_time_maf,
            )
            self.base_fee = moving_average(self.base_fee, fee, self.config.base_fee_maf)
            self.supply_change -= premium_fee

            block = Block(
                status=Status.PENDING,
                fee=premium_fee,
                proposed_at=env.now(),
                proven_at=0,
            )
            self.blocks.append(block)

            Prover(protocol=self, config=self.config, blockId=len(self.blocks) - 1)
            self.finalize_block()

            self.m_base_fee.tally(self.base_fee)
            self.m_block_time.tally(block_time)
            self.m_premium_fee.tally(premium_fee)
            self.m_supply_change.tally(self.supply_change)

    def can_prove(self, id):
        return (
            id > self.last_finalized_id
            and len(self.blocks) > id
            and self.blocks[id].status == Status.PENDING
        )

    def prove_block(self, id):
        if self.can_prove(id):
            self.blocks[id] = self.blocks[id]._replace(
                status=Status.PROVEN, proven_at=env.now()
            )
            self.finalize_block()

    def can_finalize(self):
        return (
            len(self.blocks) > self.last_finalized_id + 1
            and self.blocks[self.last_finalized_id + 1].status == Status.PROVEN
        )

    def finalize_block(self):
        for i in range(0, 5):
            if self.can_finalize():
                self.last_finalized_id += 1

                self.blocks[self.last_finalized_id] = self.blocks[
                    self.last_finalized_id
                ]._replace(status=Status.FINALIZED)

                proof_time = (
                    self.blocks[self.last_finalized_id].proven_at
                    - self.blocks[self.last_finalized_id].proposed_at
                )

                self.avg_proof_time = moving_average(
                    self.avg_proof_time,
                    proof_time,
                    self.config.block_and_proof_time_maf,
                )

                (reward, premium_reward) = self.get_proof_reward(
                    self.config.prover_reward_max_ratio, proof_time
                )

                self.base_fee = moving_average(
                    self.base_fee,
                    reward,
                    self.config.base_fee_maf,
                )

                prover_bootstrap_reward = calc_bootstrap_reward(
                    self.config.prover_reward_bootstrap,
                    self.config.prover_reward_bootstrap_day,
                    self.avg_proof_time,
                )

                self.prover_bootstrap_reward_total += prover_bootstrap_reward
                premium_reward += prover_bootstrap_reward

                self.supply_change += premium_reward

                self.m_base_fee.tally(self.base_fee)
                self.m_proof_time.tally(proof_time)
                self.m_premium_reward.tally(premium_reward)
                self.m_prover_bootstrap_reward.tally(prover_bootstrap_reward)
                self.m_supply_change.tally(self.supply_change)

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
        _proof_time_sd_pctg = get_proof_time_sd_pctg(self.config)
        yield self.hold(
            sim.Bounded(
                sim.Normal(
                    _proof_time_avg_second,
                    _proof_time_avg_second * _proof_time_sd_pctg / 100,
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
                _block_time_sd_pctg = get_block_time_sd_pctg(self.config)
                yield self.hold(
                    sim.Bounded(
                        sim.Normal(
                            _block_time_avg_second,
                            _block_time_avg_second * _block_time_sd_pctg / 100,
                        ),
                        lowerbound=1,
                    ).sample()
                )


def simulate(config, days):
    st.markdown("-----")
    st.markdown("##### Block & proof time and deviation settings")
    st.caption(
        "[block_time_avg_second, block_time_sd_pctg, proof_time_avg_minute, proof_time_sd_pctg]"
    )
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
        plot(days, [(protocol.m_base_fee, "base_fee")])
        plot(days, [(protocol.m_premium_fee, "block fee")], color="tab:green")
        plot(days, [(protocol.m_premium_reward, "proof reward")])
        plot(
            days,
            [(protocol.m_prover_bootstrap_reward, "block's prover bootstrap reward")],
        )
        plot(days, [(protocol.m_supply_change, "supply change")], color="tab:red")

        protocol.print(st)


if __name__ == "__main__":
    env = sim.Environment(trace=False)
    st.title("Taiko Block Fee/Reward Simulation")

    presents = [p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11]
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
