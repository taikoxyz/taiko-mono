import matplotlib.pyplot as plt
import streamlit as st
import numpy as np

def plot(days, sources, color='#E28BFD'):
    fig, ax = plt.subplots(figsize=(15, 5), nrows=1, ncols=1)
    for s in sources:
        data = s[0].xt()
        ax.plot(data[1], data[0], color, label=s[1])
    ax.legend(loc="lower right", fontsize=18.0)
    ax.xaxis.set_ticks(np.arange(0, 24*3600*(days+1), 24*3600))

    st.write(fig)
