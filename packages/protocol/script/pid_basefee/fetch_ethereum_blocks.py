#!/usr/bin/env python3
"""
Fetch recent Ethereum blocks data using Etherscan API
"""

import requests
import json
import time
import sys
from typing import List, Dict

ETHERSCAN_API_KEY = "ZH85M18BZKJXSUT9RWFPB8JFIHYJ19E5ER"
ETHERSCAN_BASE_URL = "https://api.etherscan.io/api"

def get_latest_block_number() -> int:
    """Get the latest Ethereum block number"""
    params = {
        "module": "proxy",
        "action": "eth_blockNumber",
        "apikey": ETHERSCAN_API_KEY
    }
    
    response = requests.get(ETHERSCAN_BASE_URL, params=params)
    data = response.json()
    
    if data.get("result"):
        return int(data["result"], 16)
    else:
        raise Exception(f"Failed to get latest block number: {data}")

def get_block_by_number(block_number: int) -> Dict:
    """Get block data by block number"""
    params = {
        "module": "proxy",
        "action": "eth_getBlockByNumber",
        "tag": hex(block_number),
        "boolean": "true",
        "apikey": ETHERSCAN_API_KEY
    }
    
    response = requests.get(ETHERSCAN_BASE_URL, params=params)
    data = response.json()
    
    if data.get("result"):
        return data["result"]
    else:
        raise Exception(f"Failed to get block {block_number}: {data}")

def fetch_recent_blocks(num_blocks: int = 10000) -> List[Dict]:
    """Fetch recent Ethereum blocks with enhanced rate limiting"""
    print(f"Fetching {num_blocks} recent Ethereum blocks...")
    print(f"This will take approximately {(num_blocks * 0.2 + (num_blocks // 100) * 2) / 60:.1f} minutes with rate limiting...")
    
    latest_block = get_latest_block_number()
    print(f"Latest block number: {latest_block}")
    
    blocks = []
    start_block = latest_block - num_blocks + 1
    
    for i, block_num in enumerate(range(start_block, latest_block + 1)):
        if i % 100 == 0:
            print(f"Progress: {i}/{num_blocks} blocks fetched ({i/num_blocks*100:.1f}%)")
            
            # Add a longer delay every 100 blocks to avoid API quota exhaustion
            if i > 0:
                print("  Pausing for 2 seconds to respect API limits...")
                time.sleep(2)
        
        try:
            block_data = get_block_by_number(block_num)
            
            # Extract relevant data
            block_info = {
                "number": int(block_data["number"], 16),
                "timestamp": int(block_data["timestamp"], 16),
                "gasLimit": int(block_data["gasLimit"], 16),
                "gasUsed": int(block_data["gasUsed"], 16),
                "baseFeePerGas": int(block_data.get("baseFeePerGas", "0x0"), 16) if block_data.get("baseFeePerGas") else 0
            }
            
            blocks.append(block_info)
            
            # Rate limiting to avoid hitting API limits (5 calls per second for free tier)
            time.sleep(0.2)
            
        except Exception as e:
            print(f"Error fetching block {block_num}: {e}")
            
            # If we hit a rate limit, wait longer before continuing
            if "rate limit" in str(e).lower() or "exceeded" in str(e).lower():
                print("Rate limit detected, waiting 10 seconds...")
                time.sleep(10)
            continue
    
    print(f"Successfully fetched {len(blocks)} blocks")
    return blocks

def save_blocks_to_file(blocks: List[Dict], filename: str = "ethereum_blocks.json"):
    """Save blocks data to JSON file"""
    with open(filename, "w") as f:
        json.dump(blocks, f, indent=2)
    print(f"Saved {len(blocks)} blocks to {filename}")

if __name__ == "__main__":
    # Allow specifying number of blocks via command line
    num_blocks = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
    
    blocks = fetch_recent_blocks(num_blocks)
    
    # Save to appropriate filename based on number of blocks
    if num_blocks == 1000:
        filename = "ethereum_blocks_1000.json"
    elif num_blocks == 10000:
        filename = "ethereum_blocks_10000.json"
    else:
        filename = f"ethereum_blocks_{num_blocks}.json"
    
    save_blocks_to_file(blocks, filename)
    
    # Print some statistics
    if blocks:
        total_gas_limit = sum(b["gasLimit"] for b in blocks)
        total_gas_used = sum(b["gasUsed"] for b in blocks)
        avg_utilization = (total_gas_used / total_gas_limit) * 100
        
        print(f"\nStatistics:")
        print(f"Average gas utilization: {avg_utilization:.2f}%")
        print(f"Average gas limit: {total_gas_limit / len(blocks):,.0f}")
        print(f"Average gas used: {total_gas_used / len(blocks):,.0f}")