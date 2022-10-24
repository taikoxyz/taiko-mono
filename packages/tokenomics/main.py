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


def calc_block_fee(fee_base, min_ratio, avg_delay, delay):
    p = fee_base
    m = fee_base * min_ratio
    b = 3 * avg_delay
    c = 6 * avg_delay
    x = delay

    if x <= b:
        return p
    elif x >= c:
        return m
    else:
        return (p-m)*(c-x)*1.0/(c-b)+m

def calc_proof_reward(fee_base, min_ratio, max_raito, avg_delay, delay):
    return min(
        fee_base * max(max_raito, 2.0 - min_ratio),
        1.0 * delay * fee_base * (1 - min_ratio) / avg_delay + fee_base * min_ratio)

def calc_bootstrap_reward(prover_reward_bootstrap, prover_reward_bootstrap_day, avg_block_time):
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
    return (ma * (maf - 1) + v) * 1.0 / maf


class Protocol(sim.Component):
    def setup(self, config):
        self.config = config
        self.fee_base = config.fee_base
        self.lamda = int(config.max_slots * config.lamda_ratio)
        self.phi = (config.max_slots + self.lamda - 1) * (config.max_slots + self.lamda)
        self.last_proposed_at = env.now()
        self.avg_block_time = 0
        self.avg_proof_time = 0
        # self.prover_reward_bootstrap_total = self.config.prover_reward_bootstrap_tota

        genesis = Block(
            status=Status.FINALIZED,
            fee=0,
            proposed_at=env.now(),
            proven_at=env.now(),
        )
        self.blocks = [genesis]
        self.last_finalized = 0
        self.mint = 0
        self.prover_bootstrap_reward_total = 0

        self.m_pending_count = sim.Monitor("pending_count", level=True, initial_tally=0)
        self.m_fee_base = sim.Monitor(
            "proof_time", level=True, initial_tally=self.fee_base
        )
        self.m_fee = sim.Monitor("fee", level=True, initial_tally=self.fee_base)
        self.m_reward = sim.Monitor("reward", level=True, initial_tally=self.fee_base)
        self.m_prover_bootstrap_reward = sim.Monitor("bootstrap_reward", level=True, initial_tally=0)
        self.m_mint = sim.Monitor("profit", level=True, initial_tally=0)
        self.m_block_time = sim.Monitor("block_time", level=True, initial_tally=0)
        self.m_proof_time = sim.Monitor("proof_time", level=True, initial_tally=0)

    def print(self, st):
        st.markdown("-----")
        st.markdown("##### Protocol state")
        st.write("lamda = {}".format(self.lamda))
        st.write("last_finalized = {}".format(self.last_finalized))
        st.write("num_blocks = {}".format(len(self.blocks)))
        st.write("fee_base = {}".format(self.fee_base))
        st.write("mint = {}".format(self.mint))
        st.write("prover_bootstrap_reward_total = {}".format(self.prover_bootstrap_reward_total))

        if self.config.prover_reward_bootstrap > 0:
            st.write("prover_bootstrap_reward_total/config.prover_reward_bootstrap = {}".format(
                self.prover_bootstrap_reward_total * 1.0/self.config.prover_reward_bootstrap
            ))

    def slot_fee(self):
        n = self.config.max_slots - self.num_pending() + self.lamda
        return self.fee_base * self.phi / n / (n - 1)

    def num_pending(self):
        return len(self.blocks) - self.last_finalized - 1

    def can_propose(self):
        return self.num_pending() < self.config.max_slots

    def propose_block(self):
        if self.can_propose():
            block_time = env.now() - self.last_proposed_at
            self.m_block_time.tally(block_time)

            self.last_proposed_at = env.now()
            if self.avg_block_time == 0:
                self.avg_block_time = block_time
            else:
                self.avg_block_time = moving_average(
                    self.avg_block_time,
                    block_time,
                    self.config.block_and_proof_time_maf,
                )

            fee = self.slot_fee()
            adjusted_fee = calc_block_fee(
                fee,
                self.config.block_fee_min_ratio,
                self.avg_block_time,
                block_time
            )

            if fee > 0: # other wise divided by 0
                self.fee_base = moving_average(
                    self.fee_base,
                    self.fee_base * adjusted_fee / fee,
                    self.config.fee_base_maf,
                )

            self.m_fee.tally(int(adjusted_fee))

            block = Block(
                status=Status.PENDING, fee=adjusted_fee, proposed_at=env.now(), proven_at=0
            )
            self.blocks.append(block)

            Prover(protocol=self, config=self.config, blockId=len(self.blocks) - 1)
            self.finalize_block()

    def can_prove(self, id):
        return (
            id > self.last_finalized
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
            len(self.blocks) > self.last_finalized + 1
            and self.blocks[self.last_finalized + 1].status == Status.PROVEN
        )

    def finalize_block(self):
        for i in range(0, 5):
            if self.can_finalize():
                self.last_finalized += 1
                self.blocks[self.last_finalized] = self.blocks[
                    self.last_finalized
                ]._replace(status=Status.FINALIZED)

                proof_time = (
                    self.blocks[self.last_finalized].proven_at
                    - self.blocks[self.last_finalized].proposed_at
                )

                self.m_proof_time.tally(proof_time)
                if self.avg_proof_time == 0:
                    self.avg_proof_time = proof_time
                else:
                    self.avg_proof_time = moving_average(
                        self.avg_proof_time,
                        proof_time,
                        self.config.block_and_proof_time_maf,
                    )

                reward = self.slot_fee()
                adjusted_reward = calc_proof_reward(
                    reward,
                    self.config.prover_reward_min_ratio,
                    self.config.prover_reward_max_ratio,
                    self.avg_proof_time,
                    proof_time
                )

                if reward > 0:
                    self.fee_base = moving_average(
                        self.fee_base,
                        self.fee_base * adjusted_reward / reward,
                        self.config.fee_base_maf,
                    )

                prover_bootstrap_reward = calc_bootstrap_reward(
                    self.config.prover_reward_bootstrap,
                    self.config.prover_reward_bootstrap_day,
                    self.avg_block_time
                )

                self.prover_bootstrap_reward_total += prover_bootstrap_reward
                adjusted_reward = prover_bootstrap_reward + adjusted_reward * (100 - self.config.prover_reward_tax_pctg) / 100.0

                self.mint += adjusted_reward - self.blocks[self.last_finalized].fee

                self.m_reward.tally(int(adjusted_reward))
                self.m_prover_bootstrap_reward.tally(prover_bootstrap_reward)
                self.m_fee_base.tally(int(self.fee_base))
                self.m_mint.tally(int(self.mint))

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
        plot(days, [(protocol.m_fee_base, "fee_base")])
        plot(days, [(protocol.m_fee, "block's proposer total fee")], color="tab:green")
        plot(days, [(protocol.m_prover_bootstrap_reward, "block's prover bootstrap reward")])
        plot(days, [(protocol.m_reward, "block's prover total reward")])
        plot(days, [(protocol.m_mint, "supply change")], color="tab:red")

        protocol.print(st)


if __name__ == "__main__":
    env = sim.Environment(trace=False)
    st.title("Taiko Block Fee/Reward Simulation")

    presents = [p0, p1, p2, p3, p4, p5, p6, p7, p8, p9]
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
