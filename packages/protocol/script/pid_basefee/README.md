# PID Base Fee Controller

This directory contains Python tools for analyzing and optimizing PID (Proportional-Integral-Derivative) controller parameters for Ethereum base fee adjustments. The tools help find optimal PID parameters by comparing simulated base fees against actual Ethereum block data.

## Overview

The PID controller implementation matches the Solidity contract `PIDBaseFeeController.sol` and uses the classic PID control formula:

```
adjustment = kP × error + kI × integral + kD × derivative
```

Where:
- **kP**: Proportional gain (responds to current error)
- **kI**: Integral gain (responds to accumulated error)
- **kD**: Derivative gain (responds to rate of error change)

All coefficients are scaled by 1000 (e.g., kP=10000 means a gain of 10.0).

## Files

- `pid_base_fee_controller.py`: Python implementation of the PID controller
- `search.py`: Grid search tool to find optimal PID parameters
- `plotter.py`: Visualization tool to plot actual vs simulated base fees
- `blocks.json`: Historical Ethereum block data (1000 blocks)

## Installation

Ensure you have Python 3 and the required packages:

```bash
pip install numpy matplotlib
```

## Usage

### 1. Finding Optimal PID Parameters

Use `search.py` to search for the best PID parameters:

```bash
# Default: optimize on first 300 blocks, verify on all 1000 blocks
python search.py

# Optimize on first 100 blocks, verify on all 1000 blocks
python search.py --optimize 100 --verify 1000

# Optimize on first 500 blocks, verify on 800 blocks
python search.py --optimize 500 --verify 800

# Show help
python search.py --help
```

The script will:
1. Search through parameter combinations (kP: 1-99, kI: 0.1-1.0, kD: 0.1-1.0)
2. Find the parameters that minimize MSE on the optimization set
3. Verify performance on the verification set
4. Save results to `optimal_pid_parameters.json`
5. Generate a verification plot

### 2. Plotting PID Performance

Use `plotter.py` to visualize how well specific PID parameters perform:

```bash
# Plot with specific PID parameters for 100 blocks
python plotter.py --PID 10000,0,1211 --blocks 100

# Plot with optimal parameters for all 1000 blocks
python plotter.py --PID 17000,100,1000 --blocks 1000

# Show help
python plotter.py --help
```

The script will:
1. Simulate base fees using the specified PID parameters
2. Compare against actual Ethereum base fees
3. Calculate error metrics (MSE, RMSE, MAE)
4. Generate a plot saved as `basefee_pid_<kP>_<kI>_<kD>__<blocks>.png`

### 3. Example Workflow

```bash
# Step 1: Find optimal parameters using first 200 blocks
python search.py --optimize 200 --verify 1000

# Step 2: Review the results in optimal_pid_parameters.json
cat optimal_pid_parameters.json

# Step 3: Plot the optimal parameters on different block ranges
# Assuming optimal parameters are kP=15000, kI=100, kD=800
python plotter.py --PID 15000,100,800 --blocks 200  # Training set
python plotter.py --PID 15000,100,800 --blocks 1000 # Full dataset

# Step 4: Test variations of the parameters
python plotter.py --PID 15000,200,800 --blocks 1000  # Higher integral
python plotter.py --PID 20000,100,800 --blocks 1000  # Higher proportional
```

## Output Files

- `optimal_pid_parameters.json`: Contains the best PID parameters found and search configuration
- `basefee_pid_<kP>_<kI>_<kD>__<blocks>.png`: Plots comparing actual vs simulated base fees
- `verification_pid_<kP>_<kI>_<kD>_all_blocks.png`: Full verification plot with error analysis

## Understanding the Results

### Error Metrics

- **MSE**: Mean Squared Error - average of squared differences
- **RMSE**: Root Mean Squared Error - square root of MSE (in wei)
- **MAE**: Mean Absolute Error - average of absolute differences
- **Mean Percentage Error**: Average percentage difference from actual values

### Interpreting Plots

The generated plots show:
1. **Top graph**: Actual base fees (blue) vs PID simulated fees (red dashed)
2. **Bottom graph** (verification plots): Prediction error over time

Lower error values indicate better PID performance. Note that PID controllers trained on a subset of blocks may not generalize well to the entire dataset due to changing gas dynamics.

## Technical Notes

### PID Coefficient Scaling

All PID coefficients (kP, kI, kD) are scaled by 1000 to match the Solidity implementation:
- Input value of 10000 = actual gain of 10.0
- Input value of 1000 = actual gain of 1.0
- Input value of 100 = actual gain of 0.1

### Error Calculation

The error is calculated as:
```python
error = parent_gas_used - gas_target
```

Where `gas_target` is typically `gas_limit / 2`.

### Search Space

The default search ranges are:
- kP: 1000 to 99000 (step 2000)
- kI: 100 to 1000 (step 100)
- kD: 100 to 1000 (step 100)

This results in ~5000 parameter combinations tested.

## Troubleshooting

1. **"Perfect straight line" issue**: If the PID output appears as a straight line, check that the error calculation is not being over-normalized.

2. **High verification error**: If parameters perform well on training data but poorly on verification data, try:
   - Using more blocks for optimization
   - Testing different optimization/verification splits
   - Checking if gas dynamics change significantly over time

3. **Memory issues**: For large block counts, the plotting may consume significant memory. Consider reducing the number of blocks or closing other applications.

## Contributing

When modifying the PID controller implementation, ensure changes are reflected in both:
1. The Python implementation (`pid_base_fee_controller.py`)
2. The Solidity contract (`PIDBaseFeeController.sol`)

Both implementations should produce identical results for the same inputs.