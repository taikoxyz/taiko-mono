import math

ETH_BLOCK_TIME = 12
GAS_TARGET = 5000000                 # target L2 gas (per ETH_BLOCK_TIME seconds)
ADJUSTMENT_QUOTIENT = 32

PROVER_REWARD_TARGET_PER_GAS = 0.1     # TAI/GAS in block rewards to prover
PROVER_TARGET_DELAY_PER_GAS = 0.001  # TODO: change to something dynamic probably

time = 0

# network fee
gas_issued = 0
last_time = time

# prover fee
basefee_proof = 0
blockreward_issued = 0


# This calculates the amount of 'Ether' (or token) based on the inputs, using an exponential function.
# Question: This one we need 
def eth_amount(value, target):
    return math.exp(value / target / ADJUSTMENT_QUOTIENT)

# This function calculates the network fee for a given amount of gas in a block
# Question: This shall be "de-coupled" from the prover - proposer TKO distribution (!?)
def network_fee(gas_in_block):
    global gas_issued
    global last_time

    gas_issued = max(0, gas_issued - GAS_TARGET * ((time - last_time)/ETH_BLOCK_TIME))
    # # # # print('Debug prints:')
    # # # # print(gas_issued)
    # # # # print(gas_in_block)
    
    # Will change based on simply elapsed time -> which  will increase the gas_issued accumulation
    cost = eth_amount(gas_issued + gas_in_block, GAS_TARGET) - eth_amount(gas_issued, GAS_TARGET)
    gas_issued = gas_issued + gas_in_block

    last_time = time

    return cost

# This function updates the base fee for proving a block, based on the amount of gas in the block and the block reward.
# Question: This shall be updated in the verifyBlock(), right ? OK
def update_basefee_proof(gas_in_block, block_reward):
    global blockreward_issued
    global basefee_proof

    # # # # print('UpdateBaseFee proof')
    # # # # print(blockreward_issued + block_reward - PROVER_REWARD_TARGET_PER_GAS * gas_in_block)
    
    blockreward_issued = max(0, blockreward_issued + block_reward - PROVER_REWARD_TARGET_PER_GAS * gas_in_block)
    basefee_proof = eth_amount(blockreward_issued/gas_in_block, PROVER_REWARD_TARGET_PER_GAS) / (PROVER_REWARD_TARGET_PER_GAS * ADJUSTMENT_QUOTIENT)
    
    # # # # print('Blockreward issued:')
    # # # # print(blockreward_issued)

    return basefee_proof

# This function calculates the prover fee for a given amount of gas in a block. 
# It simply multiplies the gas in the block by the current base fee for proving.
def prover_fee(gas_in_block):
    # # # # print('WHat is basefee_proof')
    # # # # print(basefee_proof)
    return gas_in_block * basefee_proof

# This function calculates the block reward based on the amount of gas in a block and the delay.
# This is placed in the verifyBlock() function
def calc_block_reward(gas_in_block, delay):
    # TODO: probably something else than this
    
    # Some notes:
    #  Bigger the delay, the higher the reward --> BUT actually is it ? I mean, if we calculate something on proposeBlock() it might differ (be more) when slower proof is submitted ?
    
    # # # # # Ez 'csak' a delay-en es a gas-on fugg, semmi mason.
    # # # # print("a calc block rewardban vagyok")
    # # # # print(PROVER_TARGET_DELAY_PER_GAS)
    # # # # print(gas_in_block)
    # # # # print(delay)
    # # # # print(PROVER_REWARD_TARGET_PER_GAS)
    
    return PROVER_REWARD_TARGET_PER_GAS * (delay / (PROVER_TARGET_DELAY_PER_GAS * gas_in_block))


def propose_block(gas_in_block):
    # Will not be used directly in the mechanics of prover-proposer
    print("network fee: " + str(network_fee(gas_in_block)))
    # Need to call this so that basically this will be the amount of TKO as a proposal fee
    print("prover fee: " + str(prover_fee(gas_in_block)))

# Actually during verification, we know the proposedAt and provedAt, so we can calculate delay and
# distribution there, and also update the baseFeeProof
def prove_block(gas_in_block, delay):
    block_reward = calc_block_reward(gas_in_block, delay)
    print("block reward: " + str(block_reward))
    update_basefee_proof(gas_in_block, block_reward)

print("First cross-check with Solidity starts")
propose_block(5000000)
prove_block(5000000, 300000)
print("First cross-check with Solidity ends")

propose_block(5000000)
prove_block(5000000, 20000)


propose_block(5000000)
prove_block(5000000, 20000)

print("QUICKER PROOF SUBMISSION")

propose_block(5000000)
prove_block(5000000, 250)

print("SLOWER PROOF SUBMISSION")

propose_block(5000000)
prove_block(5000000, 350)

propose_block(5000000)
prove_block(5000000, 300)

print("Cross-checked exp value")
print(eth_amount(0, 100000000))

print("See if same in solidity")
print(eth_amount(128, 2))