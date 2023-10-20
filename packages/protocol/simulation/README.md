# Simulation and Exported Data Parser and Visualization

## How to use

Assuming you are in this directory.

1. Install required packages: `python3 -m pip install -r requirements.txt`

1. Make the output directory: `mkdir -p out`

1. Run `pnpm run export:simconf` to export a new the config used in test `test_eip1559_math` to a file in `out/`, the file name will be automatically generated, for example `simconf_1697809145.txt`

1. Run `python3 simulate.py out/simconf_1697809145.txt`

Currently, every parameter set in the `test_eip1559_math` is an approximation of a possible mainnet scenario (like 10x the ethereum gas target), so you can just run the commands below to get familiar with the outcome and plots.
