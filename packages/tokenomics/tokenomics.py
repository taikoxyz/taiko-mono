# streamlit run tokenomics.py

import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st

class Proposer(sim.Component):
    def process(self):
        while True:
            Block()
            yield self.hold(sim.Uniform(2, 10).sample())


class Block(sim.Component):
    def process(self):
        if env.blocks < env.max_slots:
            env.blocks += 1
            num_blocks.tally(env.blocks)

# 

class Prover(sim.Component):
    def process(self):
        while True:
            Proof()
            yield self.hold(sim.Uniform(2,10).sample())   


class Proof(sim.Component):
    def process(self):
        if env.blocks > 0:
            env.blocks -= 1
            num_blocks.tally(env.blocks)

# # columns
# col1, col2 = st.columns([3,1])
# # sliders
# drive_time=col1.slider('drive time min',10,120)
# break_time=col1.slider('break time min',10,120)

# standard_dev1=col2.slider('standard deviation min',1,5)
# standard_dev2=col2.slider('standard deviation min',1,2)

env=sim.Environment(trace=False) 
env.max_slots = 2048
env.blocks = 0

num_blocks=sim.Monitor('num_blocks', level=True, initial_tally=0)
proposer = Proposer()
prover = Prover()

if st.button('click to run'):
    del proposer
    proposer = Proposer()
    del prover
    prover = Prover()
    env.run(till=1000)
    
tot_dist=num_blocks.xt()

fig,ax=plt.subplots(figsize=(15,5),nrows=1,ncols=1)

ax.plot(tot_dist[1],tot_dist[0],label='distance driven') 

st.write(fig)