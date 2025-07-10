#!/usr/bin/env python3
"""
Plot PID controller performance against actual Ethereum base fees.
Usage: python plotter.py --PID 10000,0,1211 --blocks 100
"""

import json
import argparse
import matplotlib.pyplot as plt
import numpy as np
from pid_base_fee_controller import PIDBaseFeeController

def load_ethereum_blocks(filename='blocks.json'):
    """Load Ethereum blocks data from JSON file."""
    with open(filename, 'r') as f:
        return json.load(f)

def simulate_base_fees(blocks, kP, kI, kD, num_blocks):
    """
    Simulate base fees using PID controller.
    
    Args:
        blocks: List of block data
        kP, kI, kD: PID coefficients (scaled by 1000)
        num_blocks: Number of blocks to simulate
        
    Returns:
        List of simulated base fees
    """
    # Use first block's base fee as initial value
    initial_base_fee = int(blocks[0]['baseFeePerGas'])
    
    # Initialize controller
    controller = PIDBaseFeeController(kP, kI, kD, initial_base_fee)
    
    # Simulate base fees
    simulated_fees = [initial_base_fee]  # Start with initial fee
    
    for i in range(1, min(num_blocks, len(blocks))):
        # Use previous block's gas used and gas limit
        parent_gas_used = int(blocks[i-1]['gasUsed'])
        gas_target = int(blocks[i-1]['gasLimit']) // 2  # gasLimit/2 as target
        
        # Update base fee
        new_base_fee = controller.update_base_fee(parent_gas_used, gas_target)
        simulated_fees.append(new_base_fee)
        
    return simulated_fees

def plot_comparison(blocks, simulated_fees, kP, kI, kD, num_blocks):
    """Plot actual vs simulated base fees."""
    # Extract actual base fees
    actual_fees = [int(block['baseFeePerGas']) for block in blocks[:num_blocks]]
    
    # Create plot
    plt.figure(figsize=(12, 6))
    
    # Plot actual and simulated fees
    x = range(num_blocks)
    plt.plot(x, actual_fees, 'b-', label='Actual Base Fee', linewidth=2)
    plt.plot(x, simulated_fees, 'r--', label='PID Simulated', linewidth=2)
    
    # Add labels and title
    plt.xlabel('Block Number')
    plt.ylabel('Base Fee (Wei)')
    plt.title(f'Base Fee Comparison - PID({kP},{kI},{kD}) - {num_blocks} Blocks')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Calculate and display MSE
    mse = np.mean((np.array(actual_fees) - np.array(simulated_fees))**2)
    plt.text(0.02, 0.98, f'MSE: {mse:.2e}', transform=plt.gca().transAxes, 
             verticalalignment='top', bbox=dict(boxstyle='round', facecolor='wheat'))
    
    # Save plot
    filename = f'basefee_pid_{kP}_{kI}_{kD}__{num_blocks}.png'
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    print(f"Plot saved as {filename}")
    
    # Also display statistics
    print(f"\nStatistics for {num_blocks} blocks:")
    print(f"MSE: {mse:.2e}")
    print(f"RMSE: {np.sqrt(mse):.2e}")
    mae = np.mean(np.abs(np.array(actual_fees) - np.array(simulated_fees)))
    print(f"MAE: {mae:.2e}")
    
    # Close plot to free memory
    plt.close()

def main():
    parser = argparse.ArgumentParser(description='Plot PID controller performance')
    parser.add_argument('--PID', type=str, required=True, 
                        help='PID coefficients as kP,kI,kD (scaled by 1000)')
    parser.add_argument('--blocks', type=int, required=True,
                        help='Number of blocks to simulate')
    
    args = parser.parse_args()
    
    # Parse PID coefficients
    try:
        kP, kI, kD = map(int, args.PID.split(','))
    except ValueError:
        print("Error: PID coefficients must be three comma-separated integers")
        return
    
    # Load data
    blocks = load_ethereum_blocks()
    
    # Check if we have enough blocks
    if args.blocks > len(blocks):
        print(f"Warning: Only {len(blocks)} blocks available, using all of them")
        num_blocks = len(blocks)
    else:
        num_blocks = args.blocks
    
    # Simulate base fees
    simulated_fees = simulate_base_fees(blocks, kP, kI, kD, num_blocks)
    
    # Plot comparison
    plot_comparison(blocks, simulated_fees, kP, kI, kD, num_blocks)

if __name__ == "__main__":
    main()