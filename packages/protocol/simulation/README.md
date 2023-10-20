# Simulation and Exported Data Parser and Visualization

## How to use

### Prerequisites

For running the `simulation_data_parser.py`, you need to install the required plugins: `(python3 -m pip install -r requirements.txt)`

_(Currently, every parameter set in the `test_eip1559_math` is an approximation of a possible mainnet scenario (like 10x the ethereum gas target), so you can just run the commands below to get familiar with the outcome and plots.)_

1. Run `pnpm run sim:export` - It will export the data into `simulation/exports` folder with a timestamp.
2. Go to `simulation` folder and run `python3 simulation_data_parser.py ./exports/simulation_data_XXXXXXXXXX.txt`
3. It will create 3 simulated plots / exported data:
   - Above
   - Below
   - Around
     the gas target.
