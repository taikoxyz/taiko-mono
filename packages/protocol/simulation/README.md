# Simulation and Exported Data Parser and Visualization

**Simulation and exported data parser+visu is ready to be (ab)used!**

## How to use

### Prerequisites

For running the `simulation_data_parser.py`, you need to install the required plugins: `(python3 -m pip install -r requirements.txt)`

_(Currently, every parameter set in the `TaikoL1.sim.sol` is an approximation of a possible mainnet scenario, so you can just run the commands below to get familiar with the outcome and plots.)_

1. Run `pnpm test:sim_export` - It will export the data into `simulation/exports` folder with a timestamp.
2. Go to `simulation` folder and run `python3 simulation_data_parser.py ./exports/simulation_data_XXXXXXXXXX.txt`
3. It will create 3 plots / exported data:
   - 4.1: Blockfee over time
   - 4.2: How many blocks proposed and verified
   - 4.3: Proof time respective to each block

**Note**: Every plot will have labels such like this:
`image`

So, the `XXXXXXXXXX_proof_time_per_block.png` figure will be definitely crowded if we run for 4000 blocks, but you will see the average (as the label shows above) OR what you could do is to change the `blocksToSimulate` in the `TaikoL1.sim.sol` to a lower number (let's say 100-200-300) but keep in mind then you should change the `startBlockProposeTime` and `upperDevToBlockProveTime` variable to a lower amount as well (imitating a test-net scenario) because proofs might not come for them (since it is set to come between 1600 and 2400).

## Parameters to tweak

- `PROOF_TIME_TARGET` -> Obvious. This is the target we have to set.
- `blocksToSimulate` -> How many blocks we would like to simulate.
- `nextBlockTime` and `minDiffToBlockPropTime` -> Currently they are set to 12 an 24 (The latter indirectly means 12+12) respectively. It means 12 is the least minimum between 2 blocks, but might be possible that not every Ethereum block will have Taiko block, but let's say on average 18s we have a Taiko block. (Sometimes 12, sometimes 24, averaging out to a 18 time.)
- `startBlockProposeTime` and `upperDevToBlockProveTime` -> It means, when should proofs come? 1600 + 800 means, somewhere between 1600 - 2400 respective to each block proposal. (If you set the `blocksToSimulate` to a small number, don't forget to change these + `PROOF_TIME_TARGET` to a reasonable level - like a testnet scenario - e.g.: 180 - 240 sec / proof)

## Observations

- Tokenomics works as expected but small deviations (between proofTimeTarget and actual proof time average) can have huge effects on the long term.
  - For example, if deviation is small, and averages around the proof time target (but below), fees will shrink.
  - If averages above the target, fees will grow.
- But since proof times are 'randomized' now (pseudo-random), it does not really reflect real mainnet (even testnet scenario) where provers might organize themselves in a way - to stop proving if not profitable.
- I think we need to communicate this clearly towards the provers so that they know what to expect.

# Added More Tests and Observations

Added more tests (and also plots under `simulation/plots`) according to the **90%-10% rule**. A possibility to have 90% quick proof and 10% slow and the other way around (90% slow, 10% quick).

## Tested Scenarios and Observations

Block number under test: 4000

### Test Scenario 1

- 90% slow (normal) proof time and 10% quick (1-5 mins)
- `proofTimeTarget` is set to approx 33 min.

**Results**: The overall average is reduced very much, so the fees converging towards zero.

See graphs starting with: `1682760421`

### Test Scenario 2

- 90% slow (normal) proof time and 10% quick (1-5 mins)
- `proofTimeTarget` is set to the previously defined average (average of test scenario 1).

(Thanks to pseudo-randomness, I was able to run the tests to get the same ‘randomly’ generated values)

**Results**: Fulfilling it averages out and fluctuates between 0.9 - 1.6 TKO ‘long term’ - meaning 4000 blocks.

See graphs starting with: `1682760720`

### Test Scenario 3

- 90% quick (1-5minsl) proof time and 10% slow (around 30mins)
- `proofTimeTarget` is set to approx. 33 mins.

**Results**: The overall average is reduced very much (even more drastically than the scenario 1), so the fees converging towards zero even quicker.

See graphs starting with: `1682761401`

### Test Scenario 4

- 90% quick (1-5minsl) proof time and 10% slow (around 30mins)
- `proofTimeTarget` is set to the average of test scenario 3.

**Results**: Fluctuates but slightly in an increasing trend over 4000 blocks - still kind of reasonable. Basically from 1 TKO to 2 TKO over the amount of blocks.

See graphs starting with: `1682761622`

### Test Scenario 5

- Same as Test scenario 3 except that `proofTimeTarget` is set to the average of test scenario 3 + 1 sec.

**Results**: Fluctuates but within a reasonable range and around 1 TKO after 4000 blocks.

See graphs starting with: `1682761795`

## Conclusion

We will be able to handle such cases where we manipulate (differ big time) the proofs time with X%, but in order to be within a reasonable range, the best would be to:

1. Define exactly the numbers on our side, like: every 10 blocks = 10% is quick / slow and stick to it.
2. Try to be as narrow with the timing intervals of those as possible (as small intervals as we can define, like not 1-5 mins, but maybe 1-2 mins).
3. When we have the numbers, approximate (simulate) the overall average.
4. Set the `proofTimeTarget` just slightly above the average, so that provers could adjust their behavior to raise the average if necessary.
5. Communicate transparently towards the provers that: this is our target proof time for you (NOT the same as `targetProofTime` because that is the overall average, with us proving quick/slow - so somewhere above that one - need to be calculated OFC) so that they could know 'what up'.
