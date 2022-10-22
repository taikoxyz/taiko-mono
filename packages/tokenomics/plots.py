import matplotlib.pyplot as plt
import streamlit as st

def plot(sources):
    fig, ax = plt.subplots(figsize=(15, 5), nrows=1, ncols=1)
    for s in sources:
        data = s[0].xt()
        ax.plot(data[1], data[0], label=s[1])
    ax.legend(loc="lower right", fontsize = 18.0)
    st.write(fig)

