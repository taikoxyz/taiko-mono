import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import streamlit as st
import numpy as np


@ticker.FuncFormatter
def major_formatter(x, pos):
    return "d%d" % (x / 24 / 3600)


def plot(days, sources, color="#E28BFD"):
    fig, ax = plt.subplots(figsize=(15, 5), nrows=1, ncols=1)
    for s in sources:
        data = s[0].xt()
        ax.plot(data[1], data[0], color, label=s[1])
    ax.legend(loc="lower center", fontsize=18.0)
    ax.xaxis.set_ticks(np.arange(0, 24 * 3600 * (days + 1), 24 * 3600))
    ax.xaxis.set_tick_params(labelrotation=45)
    ax.xaxis.set_major_formatter(major_formatter)

    st.write(fig)
