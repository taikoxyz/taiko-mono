# streamlit run tokenomics.py

import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st
from enum import Enum
from typing import NamedTuple
from plots import plot

F_PROFIT = 512
F_TIME = 1024
DAY = 24 * 3600
BASE = 10
BASE_FACTOR = 1024


class SimConfig(NamedTuple):
    max_slots: int
    lamda_ratio: float
    base_fee: int

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
    _max_fee = max(2*min_fee-base_fee, max_fee)*1.0
    return min(_max_fee, 1.0 * delay * (base_fee - min_fee)/avg_delay + min_fee)


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
        st.write("protocol.config = {}".format(config))
        st.write("protocol.lamda = {}".format(self.lamda))

        genesis = Block(
            status=Status.FINALIZED, fee = 0, proposed_at=env.now(), proven_at=env.now()
        )
        self.blocks = [genesis]
        self.last_finalized = 0
        self.mint = 0

        self.m_pending_count = sim.Monitor("pending_count", level=True, initial_tally=0)
        self.m_base_fee = sim.Monitor("proof_time", level=True, initial_tally=self.base_fee)
        self.m_fee = sim.Monitor("fee", level=True, initial_tally=self.base_fee)
        self.m_reward = sim.Monitor("reward", level=True,initial_tally=self.base_fee)
        self.m_mint = sim.Monitor("profit", level=True, initial_tally=0)
        self.m_block_time = sim.Monitor("block_time", level=True, initial_tally=0)
        self.m_proof_time = sim.Monitor("proof_time", level=True, initial_tally=0)

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
                self.avg_block_time = (
                    (F_TIME - 1) * self.avg_block_time + block_time
                ) / F_TIME

            fee = self.slot_fee()
            # self.avg_profit = (
            #     (F_PROFIT - 1) * self.avg_profit + self.mint
            # ) / F_PROFIT
            self.m_fee.tally(fee)

            block = Block(status=Status.PENDING, fee = fee, proposed_at=env.now(), proven_at=0)
            # print("block {} proposed at {}".format(len(self.blocks), env.now()))
            self.blocks.append(block)

            Prover(blockId=len(self.blocks) - 1)
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
                    self.avg_proof_time = (
                        (F_TIME - 1) * self.avg_proof_time + proof_time
                    ) / F_TIME

                reward = self.slot_fee()
                adjustedReward = calc_proving_fee(
                    reward,
                    0.75*reward,
                    2*reward,
                    self.avg_proof_time,
                    proof_time)
                print("reward {}".format(reward))
                 

                self.base_fee = (self.base_fee * (BASE_FACTOR - 1) + self.base_fee * adjustedReward / reward)*1.0 / BASE_FACTOR


                mint = adjustedReward - self.blocks[self.last_finalized].fee
                self.mint += mint

                # self.avg_profit = (
                #     (F_PROFIT - 1) * self.avg_profit + self.mint
                # ) / F_PROFIT
                self.m_reward.tally(adjustedReward)
                self.m_base_fee.tally(self.base_fee)
                self.m_mint.tally(self.mint)

            else:
                break

        self.m_pending_count.tally(self.num_pending())


class Prover(sim.Component):
    def setup(self, blockId):
        self.blockId = blockId

    def process(self):
        yield self.hold(
            sim.Bounded(
                sim.Normal(get_avg_proof_time(), get_avg_proof_time() * sd_proof_time / 100),
                lowerbound=1,
            ).sample()
        )
        protocol.prove_block(self.blockId)


class Proposer(sim.Component):
    def process(self):
        while True:
            if protocol.can_propose():
                protocol.propose_block()

                yield self.hold(
                    sim.Bounded(
                        sim.Normal(
                            get_avg_block_time(), get_avg_block_time() * sd_block_time / 100
                        ),
                        lowerbound=1,
                    ).sample()
                )
            else:
                yield self.hold(1)




def get_avg_block_time():
    return avg_block_time
    # if env.now() < DAY:
    #     return avg_block_time
    # elif env.now() < 3 * DAY:
    #     return 2 * avg_block_time
    # else:
    #     return avg_block_time

def get_avg_proof_time():
    return avg_proof_time
    # if env.now() < 2 * DAY:
    #     return avg_proof_time
    # elif env.now() < 4 * DAY:
    #     return 3 * avg_proof_time
    # else:
    #     return avg_proof_time

if __name__ == "__main__":
    # # columns
    col1, col2 = st.columns([3, 2])
    # # sliders
    avg_block_time = col1.slider("avg block time (second)", 10, 120, 15)
    avg_proof_time = col1.slider("avg proof time (minute)", 15, 60, 45) * 60

    sd_block_time = col2.slider("deviation block time", 0, 100, 20)
    sd_proof_time = col2.slider("deviation proof time", 0, 100, 25)

    if st.button("click to run", key="tokenomics"):
        env = sim.Environment(trace=False)

        protocol = None
        proposer = None
        expected_pending_blocks = int(2 * avg_proof_time / avg_block_time)
        st.write("expected_pending_blocks = {}".format(expected_pending_blocks))

        config = SimConfig(max_slots = 10000,
            lamda_ratio = 1.8,
            base_fee = 10.0)

        protocol = Protocol(config=config)
        proposer = Proposer()

        env.run(till = 10 * DAY)

        plot([(protocol.m_block_time, "block time")])
        plot([(protocol.m_proof_time, "proof time")])
        plot([(protocol.m_pending_count, "num pending")])

        st.write("Fees and Rewards")
        plot([(protocol.m_base_fee, "base"),
            (protocol.m_fee, "fee"),
            (protocol.m_reward, "reward")])
        plot([(protocol.m_mint, "mint")])
