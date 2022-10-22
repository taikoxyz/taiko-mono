# streamlit run main.py

import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st
from enum import Enum
from typing import NamedTuple
from plots import plot
import pandas as pd
import numpy as np
from present import Config, Present
from presents.p1 import present as p1
from presents.p2 import present as p2

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

def calc_proving_fee(base_fee, min_fee, max_fee, avg_delay, delay):
    _max_fee = max(2 * min_fee - base_fee, max_fee) * 1.0
    return min(_max_fee, 1.0 * delay * (base_fee - min_fee) / avg_delay + min_fee)

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
        self.base_fee = config.base_fee
        self.lamda = int(config.max_slots * config.lamda_ratio)
        self.phi = (config.max_slots + self.lamda - 1) * (config.max_slots + self.lamda)
        self.last_proposed_at = env.now()
        self.avg_block_time = 0
        self.avg_proof_time = 0
        # self.avg_profit = 0

        genesis = Block(
            status=Status.FINALIZED, fee=0, proposed_at=env.now(), proven_at=env.now()
        )
        self.blocks = [genesis]
        self.last_finalized = 0
        self.mint = 0

        self.m_pending_count = sim.Monitor("pending_count", level=True, initial_tally=0)
        self.m_base_fee = sim.Monitor(
            "proof_time", level=True, initial_tally=self.base_fee
        )
        self.m_fee = sim.Monitor("fee", level=True, initial_tally=self.base_fee)
        self.m_reward = sim.Monitor("reward", level=True, initial_tally=self.base_fee)
        self.m_mint = sim.Monitor("profit", level=True, initial_tally=0)
        self.m_block_time = sim.Monitor("block_time", level=True, initial_tally=0)
        self.m_proof_time = sim.Monitor("proof_time", level=True, initial_tally=0)

    def print(self, st):
        st.markdown("-----")
        st.markdown("##### Protocol internal variables")
        st.write("lamda = {}".format(self.lamda))
        st.write("last_finalized = {}".format(self.last_finalized))
        st.write("num_blocks = {}".format(len(self.blocks)))
        st.write("mint = {}".format(self.mint))

    def slot_fee(self):
        n = self.config.max_slots - self.num_pending() + self.lamda
        return self.base_fee * self.phi / n / (n - 1)

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
                    self.config.block_and_proof_time_maf)

            fee = self.slot_fee()
            self.m_fee.tally(fee)

            block = Block(
                status=Status.PENDING, fee=fee, proposed_at=env.now(), proven_at=0
            )
            # print("block {} proposed at {}".format(len(self.blocks), env.now()))
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
            # print("block {} proven at {}".format(id, env.now()))
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
                # print("block {} finalized at {}".format(self.last_finalized, env.now()))

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
                        self.config.block_and_proof_time_maf)

                reward = self.slot_fee()
                adjustedReward = calc_proving_fee(
                    reward,
                    self.config.reward_min_ratio * reward,
                    self.config.reward_max_ratio * reward,
                    self.avg_proof_time,
                    proof_time
                )

                self.base_fee = moving_average(
                    self.base_fee,
                    self.base_fee * adjustedReward / reward,
                    self.config.base_fee_maf)

                self.mint += adjustedReward - self.blocks[self.last_finalized].fee

                self.m_reward.tally(adjustedReward)
                self.m_base_fee.tally(self.base_fee)
                self.m_mint.tally(self.mint)

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
                    _proof_time_avg_second
                    * _proof_time_sd_pctg
                    / 100,
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
                            _block_time_avg_second
                            * _block_time_sd_pctg
                            / 100,
                        ),
                        lowerbound=1,
                    ).sample()
                )

def simulate(config):
    st.markdown("-----")
    st.markdown("##### Block & proof time and deviation settings")
    st.caption("[block_time_avg_second, block_time_sd_pctg, proof_time_avg_minute, proof_time_sd_pctg]")
    time_str = ""
    for t in config.timing:
        time_str += str(t._asdict().values())
    st.write(time_str.replace("dict_values","  ☀️").replace("(","").replace(")",""))

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
    if st.button("Click to run", key="run"):
        actual_config = Config(timing=config.timing, **inputs)

        protocol = Protocol(config=actual_config)
        proposer = Proposer(protocol=protocol)

        env.run(till= 7 * DAY)

        st.markdown("-----")
        st.markdown("##### Results")

        plot([(protocol.m_block_time, "block time")])
        plot([(protocol.m_proof_time, "proof time")])
        plot([(protocol.m_pending_count, "num pending")])

        plot([(protocol.m_base_fee, "base"),(protocol.m_fee, "proposer fee")])
        plot([(protocol.m_reward, "prover reward")])
        plot([(protocol.m_mint, "TKO supply change")])

        protocol.print(st)

if __name__ == "__main__":
    env = sim.Environment(trace=False)
    st.title("Taiko Tokenomics Simulation")

    presents = [p1, p2]
    st.markdown("## Configs")
    selected = st.radio(
        "Please choose one of the following predefined configs:",
        range(0, len(presents)),
        format_func=lambda x: presents[x].title,
    )
    present = presents[selected]
    st.markdown("-----")
    st.markdown("##### About this config")
    st.markdown(present.desc)
    simulate(present.config)
