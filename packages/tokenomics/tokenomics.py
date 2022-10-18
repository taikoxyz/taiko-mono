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
    def setup(self, max_slots):
        self.max_slots = max_slots
        genesis = Block(
            status = Status.FINALIZED,
            proposedAt= env.now(),
            provenAt= env.now())
        self.blocks=[genesis]
        self.last_finalized = 0

        self.num_blocks=sim.Monitor('num_blocks', level=True, initial_tally=0)

    def num_pending(self):
        return len(self.blocks) - self.last_finalized - 1

    def can_propose(self):
        return self.num_pending() < self.max_slots

    def propose_block(self):
        if self.can_propose():
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
                self.last_finalized += 1
                self.blocks[self.last_finalized] = self.blocks[self.last_finalized]._replace(status = Status.FINALIZED)
                print("block {} finalized at {}".format(self.last_finalized, env.now()))
            else:
                break
        self.num_blocks.tally(self.num_pending())

class Prover(sim.Component):
    def setup(self, blockId):
        self.blockId = blockId

    def process(self):
        yield self.hold(sim.Normal(30*60, 0).sample())
        protocol.prove_block(self.blockId)

class Proposer(sim.Component):
    def process(self):
        while True:
            if protocol.can_propose():
                protocol.propose_block()
                yield self.hold(sim.Normal(60, 0).sample())
            else:
                yield self.hold(1)

# class Proposer(sim.Component):
#     def process(self):
#         while True:
#             if len(env.blocks) < env.max_slots:
#                 block = (0, 0)
#                 env.blocks.append(block)
#             yield self.hold(sim.Uniform(2, 10).sample())


# # columns
# col1, col2 = st.columns([3,1])
# # sliders
# drive_time=col1.slider('drive time min',10,120)
# break_time=col1.slider('break time min',10,120)

# standard_dev1=col2.slider('standard deviation min',1,5)
# standard_dev2=col2.slider('standard deviation min',1,2)

env=sim.Environment(trace=False) 

protocol = Protocol(max_slots=1024)
proposer = Proposer()

if st.button('click to run'):
    del protocol
    del proposer
    protocol = Protocol(max_slots=64)
    proposer = Proposer()
    env.run(till=144000)
    
tot_dist=protocol.num_blocks.xt()

fig,ax=plt.subplots(figsize=(15,5),nrows=1,ncols=1)

ax.plot(tot_dist[1],tot_dist[0],label='distance driven') 

st.write(fig)