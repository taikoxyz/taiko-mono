# streamlit run tokenomics.py

import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st

class Comp(sim.Component):
    def process(self):
        while True:
            data.tally(sim.Normal(100, 10).sample())
            yield self.hold(1)


env=sim.Environment(trace=False) 
env.max_slots = 2048
env.blocks = 0

data=sim.Monitor('data', level=True, initial_tally=0)
comp = Comp()

if st.button('click to run'):
    del data
    del comp
    data=sim.Monitor('data', level=True, initial_tally=0)
    comp = Comp()
    env.run(till=1000)
    
data_dist=data.xt()

fig,ax=plt.subplots(figsize=(15,5),nrows=1,ncols=1)

ax.plot(data_dist[1],data_dist[0],label='distance driven') 

st.write(fig)