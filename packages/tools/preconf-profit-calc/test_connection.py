#!/usr/bin/env python3
"""Test script to verify Web3 connection and environment setup"""

import os
from dotenv import load_dotenv
from web3 import Web3

# Load environment variables
load_dotenv()

def test_connection():
    rpc_url = os.getenv('RPC_URL')
    if not rpc_url:
        print("❌ RPC_URL not set in .env file")
        return False
    
    print(f"Testing connection to: {rpc_url}")
    
    try:
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        if w3.is_connected():
            print(f"✅ Connected to Ethereum node")
            print(f"   Client version: {w3.client_version}")
            print(f"   Current block: {w3.eth.block_number}")
            print(f"   Chain ID: {w3.eth.chain_id}")
            return True
        else:
            print("❌ Failed to connect to Ethereum node")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == '__main__':
    print("=== Testing Taiko L1 Cost Calculator Setup ===\n")
    
    # Check if .env exists
    if not os.path.exists('.env'):
        print("❌ .env file not found. Please copy .env.example to .env and configure it.")
        exit(1)
    
    # Test connection
    if test_connection():
        print("\n✅ Setup is complete! You can now run step1_event_monitor.py")
    else:
        print("\n❌ Please check your RPC_URL in .env file")