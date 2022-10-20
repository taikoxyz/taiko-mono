# https://www.desmos.com/calculator/vribuvxpn7
# streamlit run timeincentive.py

import salabim as sim
import matplotlib.pyplot as plt
import streamlit as st
from plots import plot

def t_rel(x):
    return max(0, min(1, x))

def f_pos(x):
    a = R * t_rel(x)
    return a / (a + 1 - R)

def f_neg(x):
    b = R * t_rel(-x)
    return -b / (b + 1 - R)

# returns [0, 1] for input [-1, 1]
def sigmoid(x):
    return (f_pos(x) +f_neg(x))/R

def discount(delay, avg_delay, bigger_better, max_discount, max_premium, max_span):
    if avg_delay == 0 or delay==0:
        return 1.0
    if delay <= 2 * avg_delay:
        return 1.0

    if bigger_better:
        change = 1.0 * (delay - avg_delay) / avg_delay
    else:
        change = 1.0 * (avg_delay - delay) / delay

    if change > 0:
        change /= max_span  # up to +-400% change

    c = sigmoid(change)
    if c > 0:
        c *= (max_premium - 1)
    else:
        c *= (1 - max_discount)
    return 1 + c


def reward_discount(delay, avg_delay):
    return discount(delay, avg_delay, True, REWARD_MAX_DISCOUNT, REWARD_MAX_PREMIUM, 10)

def fee_discount(delay, avg_delay):
    return discount(delay, avg_delay, False, FEE_MAX_DISCOUNT, FEE_MAX_PREMIUM, 5)


class Simulator(sim.Component):
    def setup(self):
        self.i = 0
    def process(self):
        while True:
            self.i += 1
            m_fee_discount.tally(fee_discount(self.i, AVERAGE_TIME))
            m_reward_discount.tally(reward_discount(self.i, AVERAGE_TIME))
            yield self.hold(1)

AVERAGE_TIME = 100
FEE_MAX_PREMIUM = 2
FEE_MAX_DISCOUNT = 0.5
REWARD_MAX_PREMIUM = 4
REWARD_MAX_DISCOUNT = 0.5
R = 0.7


if __name__ == "__main__":
    env = sim.Environment(trace=False)

    m_fee_discount = sim.Monitor("fee_discount", level=True, initial_tally=0)
    m_reward_discount = sim.Monitor("reward_discount", level=True, initial_tally=0)

    st.write("Time-based incentive (discount & premium)")
    st.write("average block/proof time = {}".format(AVERAGE_TIME))
    if st.button("click to run"):
        Simulator()
        env.run(till = AVERAGE_TIME*20)
        plot([(m_fee_discount, "Fee%"), (m_reward_discount, "Reward%")])



