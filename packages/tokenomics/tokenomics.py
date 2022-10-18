# streamlit run tokenomics.py

import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st
from enum import Enum 
from typing import NamedTuple

class Status(Enum):
    PENDING = 1
    PROVEN = 2
    FINALIZED = 3

class Block(NamedTuple):
    status: Status
    proposedAt: int
    provenAt: int

class Protocol(sim.Component):
    def setup(self, max_slots, f_min, lamda_ratio):
        self.max_slots = max_slots
        self.f_min = f_min
        self.lamda = int(self.max_slots * lamda_ratio)
        self.phi = (self.max_slots + self.lamda - 1) * (self.max_slots + self.lamda)
        st.write("protocol.max_slots = {}".format(max_slots))
        st.write("protocol.lamda = {}".format(self.lamda))
        st.write("protocol.f_min = {}".format(self.f_min))

        genesis = Block(
            status = Status.FINALIZED,
            proposedAt= env.now(),
            provenAt= env.now())
        self.blocks=[genesis]
        self.last_finalized = 0
        self.m_pending_count=sim.Monitor('pending_count', level=True, initial_tally=0)
        
        self.profit = 0
        self.m_profit = sim.Monitor('profit', level=True, initial_tally=0)
        self.m_fee= sim.Monitor('fee', level=True, initial_tally=0)
        self.m_reward = sim.Monitor('reward', level=True, initial_tally=0)

    def fee(self):
        n = self.max_slots - self.num_pending() + self.lamda
        return self.f_min*self.phi / n / (n-1)

    def reward(self):
        n = self.max_slots - self.num_pending() + self.lamda
        return self.f_min*self.phi / n / (n+1)

    def num_pending(self):
        return len(self.blocks) - self.last_finalized - 1

    def can_propose(self):
        return self.num_pending() < self.max_slots

    def propose_block(self):
        if self.can_propose():
            fee = self.fee()
            self.profit += fee
            self.m_fee.tally(fee)
            self.m_profit.tally(self.profit)

            block = Block(
                status = Status.PENDING,
                proposedAt= env.now(),
                provenAt= 0)
            print("block {} proposed at {}".format(len(self.blocks), env.now()))
            self.blocks.append(block)

            Prover(blockId = len(self.blocks) - 1)
            self.finalize_block()


    def can_prove(self, id):
        return (id > self.last_finalized and
            len(self.blocks) > id and
            self.blocks[id].status == Status.PENDING)

    def prove_block(self, id):
        if self.can_prove(id):
            self.blocks[id] = self.blocks[id]._replace(
                status = Status.PROVEN,
                provenAt = env.now())
            print("block {} proven at {}".format(id, env.now()))
            self.finalize_block()


    def can_finalize(self):
        return (len(self.blocks) > self.last_finalized + 1 and
            self.blocks[self.last_finalized + 1].status == Status.PROVEN)

    def finalize_block(self):
        for i in range(0, 5):
            if self.can_finalize():
                reward = self.reward()
                self.profit -= reward
                self.m_reward.tally(reward)
                self.m_profit.tally(self.profit)

                self.last_finalized += 1
                self.blocks[self.last_finalized] = self.blocks[self.last_finalized]._replace(status = Status.FINALIZED)
                print("block {} finalized at {}".format(self.last_finalized, env.now()))
            else:
                break

        self.m_pending_count.tally(self.num_pending())

class Prover(sim.Component):
    def setup(self, blockId):
        self.blockId = blockId

    def process(self):
        yield self.hold(sim.Normal(avg_proof_time, 2*60).sample())
        protocol.prove_block(self.blockId)

class Proposer(sim.Component):
    def process(self):
        while True:
            if protocol.can_propose():
                protocol.propose_block()
                yield self.hold(sim.Normal(avg_block_time, 1).sample())
            else:
                yield self.hold(1)

# # columns
col1, col2 = st.columns([3,1])
# # sliders
avg_block_time=col1.slider('avg block time (second)',10, 120)
avg_proof_time=col1.slider('avg proof time (minute)',15, 60) * 60

# standard_dev1=col2.slider('standard deviation min',1,5)
# standard_dev2=col2.slider('standard deviation min',1,2)

env=sim.Environment(trace=False) 

protocol = None
proposer = None

def plot(sources):
    fig,ax=plt.subplots(figsize=(15,5),nrows=1,ncols=1)
    for s in sources:
        data=s[0].xt()
        ax.plot(data[1],data[0],label=s[1]) 
    ax.legend(loc="lower right")
    st.write(fig)
   
if st.button('click to run'):
    expected_pending_blocks = int(2 * avg_proof_time / avg_block_time)
    st.write("expected_pending_blocks = {}".format(expected_pending_blocks))

    del protocol
    del proposer
    protocol = Protocol(
        max_slots = 2 * expected_pending_blocks,
        f_min = 100.0,
        lamda_ratio = 1.8)

    proposer = Proposer()

    env.run(till=12*60*60) ## 12 hours
    
    plot([(protocol.m_pending_count, "num pending")])
    plot([(protocol.m_fee, "fee"),
        (protocol.m_reward, "reward")])
