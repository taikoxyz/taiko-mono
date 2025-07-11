#!/usr/bin/env python3
"""
Find optimal PID parameters to match actual Ethereum base fees.
Search ranges:
- kP: 1 to 99 (scaled to 1000-99000)
- kI: 0.1 to 1.0 (scaled to 100-1000)
- kD: 0.1 to 1.0 (scaled to 100-1000)
"""

import json
import numpy as np
from itertools import product
from pid_base_fee_controller import PIDBaseFeeController
import matplotlib.pyplot as plt

def load_ethereum_blocks(filename='blocks.json'):
    """Load Ethereum blocks data from JSON file."""
    with open(filename, 'r') as f:
        return json.load(f)

def calculate_mse(blocks, kP, kI, kD, num_blocks=None):
    """
    Calculate MSE between actual and simulated base fees.
    
    Args:
        blocks: List of block data
        kP, kI, kD: PID coefficients (scaled by 1000)
        num_blocks: Number of blocks to use (None = all)
        
    Returns:
        MSE value
    """
    if num_blocks is None:
        num_blocks = len(blocks)
    else:
        num_blocks = min(num_blocks, len(blocks))
    
    # Use first block's base fee as initial value
    initial_base_fee = int(blocks[0]['baseFeePerGas'])
    
    # Initialize controller
    controller = PIDBaseFeeController(kP, kI, kD, initial_base_fee)
    
    # Simulate and calculate MSE
    mse = 0
    actual_fees = []
    simulated_fees = []
    
    # First block - no simulation needed
    actual_fees.append(initial_base_fee)
    simulated_fees.append(initial_base_fee)
    
    for i in range(1, num_blocks):
        # Actual base fee
        actual_fee = int(blocks[i]['baseFeePerGas'])
        actual_fees.append(actual_fee)
        
        # Simulate using previous block's data
        parent_gas_used = int(blocks[i-1]['gasUsed'])
        gas_target = int(blocks[i-1]['gasLimit']) // 2
        
        simulated_fee = controller.update_base_fee(parent_gas_used, gas_target)
        simulated_fees.append(simulated_fee)
        
        # Add to MSE
        error = actual_fee - simulated_fee
        mse += error ** 2
    
    return mse / num_blocks, actual_fees, simulated_fees

def grid_search(blocks, num_blocks=100):
    """
    Perform grid search to find optimal PID parameters.
    
    Args:
        blocks: List of block data
        num_blocks: Number of blocks to use for optimization
        
    Returns:
        Best kP, kI, kD and corresponding MSE
    """
    # Define search ranges
    kP_range = range(1, 1000, 1)  # 1 to 99, step 2 (will be scaled by 1000)
    kI_range = np.arange(1, 10, 0.1)  # 0.1 to 1.0, step 0.1
    kD_range = np.arange(1, 10, 0.1)  # 0.1 to 1.0, step 0.1
    
    best_mse = float('inf')
    best_params = None
    
    total_combinations = len(kP_range) * len(kI_range) * len(kD_range)
    print(f"Searching {total_combinations} parameter combinations...")
    
    # Track progress
    count = 0
    
    for kP_base, kI_base, kD_base in product(kP_range, kI_range, kD_range):
        # Scale coefficients
        kP = int(kP_base * 1000)
        kI = int(kI_base * 1000)
        kD = int(kD_base * 1000)
        
        # Calculate MSE
        mse, _, _ = calculate_mse(blocks, kP, kI, kD, num_blocks)
        
        # Update best if improved
        if mse < best_mse:
            best_mse = mse
            best_params = (kP, kI, kD)
            print(f"New best: kP={kP}, kI={kI}, kD={kD}, MSE={mse:.2e}")
        
        count += 1
        if count % 100 == 0:
            print(f"Progress: {count}/{total_combinations} ({100*count/total_combinations:.1f}%)")
    
    return best_params, best_mse

def verify_parameters(blocks, kP, kI, kD):
    """
    Verify PID parameters on all 1000 blocks.
    
    Args:
        blocks: List of block data
        kP, kI, kD: Optimal PID coefficients
    """
    print(f"\nVerifying PID({kP},{kI},{kD}) on all {len(blocks)} blocks...")
    
    mse, actual_fees, simulated_fees = calculate_mse(blocks, kP, kI, kD)
    
    # Calculate additional metrics
    rmse = np.sqrt(mse)
    mae = np.mean(np.abs(np.array(actual_fees) - np.array(simulated_fees)))
    
    # Calculate percentage errors
    percent_errors = []
    for actual, simulated in zip(actual_fees[1:], simulated_fees[1:]):  # Skip first block
        if actual > 0:
            percent_error = abs(actual - simulated) / actual * 100
            percent_errors.append(percent_error)
    
    mean_percent_error = np.mean(percent_errors)
    max_percent_error = np.max(percent_errors)
    
    print(f"\nResults on all {len(blocks)} blocks:")
    print(f"MSE: {mse:.2e}")
    print(f"RMSE: {rmse:.2e}")
    print(f"MAE: {mae:.2e}")
    print(f"Mean Percentage Error: {mean_percent_error:.2f}%")
    print(f"Max Percentage Error: {max_percent_error:.2f}%")
    
    # Plot full verification
    plt.figure(figsize=(15, 8))
    
    # Main plot
    plt.subplot(2, 1, 1)
    x = range(len(blocks))
    plt.plot(x, actual_fees, 'b-', label='Actual Base Fee', linewidth=1)
    plt.plot(x, simulated_fees, 'r--', label='PID Simulated', linewidth=1)
    plt.xlabel('Block Number')
    plt.ylabel('Base Fee (Wei)')
    plt.title(f'Full Verification - PID({kP},{kI},{kD}) - {len(blocks)} Blocks')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Error plot
    plt.subplot(2, 1, 2)
    errors = np.array(actual_fees) - np.array(simulated_fees)
    plt.plot(x, errors, 'g-', linewidth=1)
    plt.axhline(y=0, color='k', linestyle='-', alpha=0.3)
    plt.xlabel('Block Number')
    plt.ylabel('Error (Actual - Simulated)')
    plt.title('Prediction Error')
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    filename = f'verification_pid_{kP}_{kI}_{kD}_all_blocks.png'
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    print(f"\nVerification plot saved as {filename}")
    plt.close()

def main():
    import argparse
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Find optimal PID parameters for base fee control')
    parser.add_argument('--optimize', type=int, default=300,
                        help='Number of blocks to use for optimization (default: 300)')
    parser.add_argument('--verify', type=int, default=1000,
                        help='Number of blocks to use for verification (default: 1000)')
    args = parser.parse_args()
    
    # Load data
    blocks = load_ethereum_blocks()
    print(f"Loaded {len(blocks)} blocks")
    
    # Validate arguments
    if args.optimize > len(blocks):
        print(f"Warning: Only {len(blocks)} blocks available, using all for optimization")
        args.optimize = len(blocks)
    if args.verify > len(blocks):
        print(f"Warning: Only {len(blocks)} blocks available, using all for verification")
        args.verify = len(blocks)
    
    # Find optimal parameters using specified number of blocks
    print(f"\nSearching for optimal PID parameters using first {args.optimize} blocks...")
    best_params, best_mse = grid_search(blocks, num_blocks=args.optimize)
    
    if best_params:
        kP, kI, kD = best_params
        print(f"\nBest parameters found:")
        print(f"kP = {kP} (base: {kP/1000})")
        print(f"kI = {kI} (base: {kI/1000})")
        print(f"kD = {kD} (base: {kD/1000})")
        print(f"MSE on first {args.optimize} blocks: {best_mse:.2e}")
        
        # Verify on specified number of blocks
        verify_blocks = blocks[:args.verify]
        verify_parameters(verify_blocks, kP, kI, kD)
        
        # Save results
        results = {
            'optimal_parameters': {
                'kP': kP,
                'kI': kI,
                'kD': kD,
                'kP_base': kP/1000,
                'kI_base': kI/1000,
                'kD_base': kD/1000
            },
            f'mse_{args.optimize}_blocks': best_mse,
            'search_config': {
                'kP_range': '1-99',
                'kI_range': '0.1-1.0',
                'kD_range': '0.1-1.0',
                'optimization_blocks': args.optimize,
                'verification_blocks': args.verify
            }
        }
        
        with open('optimal_pid_parameters.json', 'w') as f:
            json.dump(results, f, indent=2)
        print("\nOptimal parameters saved to optimal_pid_parameters.json")

if __name__ == "__main__":
    main()