#!/usr/bin/env python3
"""
Step 1: Barebone Event Monitor
Subscribes to TaikoInbox events and prints them to console
"""

import os
import sys
import time
import json
from typing import Optional
from dotenv import load_dotenv
import click
from web3 import Web3
from web3.exceptions import BlockNotFound

# Load environment variables
load_dotenv()

# Event signatures (will be replaced with ABI in later steps)
EVENT_SIGNATURES = {
    'BatchProposed': '0x5e51a11eb3e8d3d27b9c6e9a39ad56b2b1af901f7fb3cb12c287f5fda9734ae8',
    'BatchesProved': '0x4b0a8ebb0ed168b1db012536695fd998d45e682535a0997e5f972fdc21b61277',
    'BatchesVerified': '0xd44418beea9b9f75cfa28aff0429a8d70a3947a645304bc426c7ed5332c9c184'
}

class EventMonitor:
    def __init__(self, rpc_url: str, inbox_address: str):
        """Initialize the event monitor with Web3 connection"""
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        if not self.w3.is_connected():
            raise Exception("Failed to connect to Ethereum node")
        
        self.inbox_address = Web3.to_checksum_address(inbox_address)
        print(f"Connected to Ethereum node: {self.w3.client_version}")
        print(f"Monitoring TaikoInbox at: {self.inbox_address}")
        print(f"Current block: {self.w3.eth.block_number}")
        print("-" * 80)
    
    def get_events_in_block(self, block_number: int):
        """Get all relevant events from a specific block"""
        try:
            block = self.w3.eth.get_block(block_number, full_transactions=True)
            
            # Get all logs for this block filtered by our contract
            logs = self.w3.eth.get_logs({
                'fromBlock': block_number,
                'toBlock': block_number,
                'address': self.inbox_address
            })
            
            events = []
            for log in logs:
                # Check if this log matches any of our event signatures
                topic0 = log['topics'][0].hex() if log['topics'] else None
                
                for event_name, signature in EVENT_SIGNATURES.items():
                    if topic0 == signature:
                        events.append({
                            'event_name': event_name,
                            'block_number': block_number,
                            'transaction_hash': log['transactionHash'].hex(),
                            'log_index': log['logIndex'],
                            'topics': [topic.hex() for topic in log['topics']],
                            'data': log['data'].hex() if log['data'] else '0x',
                            'timestamp': block['timestamp']
                        })
                        break
            
            return events
            
        except BlockNotFound:
            print(f"Block {block_number} not found, waiting...")
            return []
        except Exception as e:
            print(f"Error processing block {block_number}: {e}")
            return []
    
    def print_event(self, event: dict):
        """Pretty print an event to console"""
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(event['timestamp']))
        
        print(f"\n[{timestamp}] {event['event_name']} Event")
        print(f"  Block: {event['block_number']}")
        print(f"  Transaction: {event['transaction_hash']}")
        print(f"  Log Index: {event['log_index']}")
        
        # Print raw data for now (will be parsed in Step 2)
        print(f"  Topics:")
        for i, topic in enumerate(event['topics']):
            print(f"    [{i}] {topic}")
        
        if event['data'] != '0x':
            print(f"  Data: {event['data'][:66]}..." if len(event['data']) > 66 else f"  Data: {event['data']}")
    
    def monitor_blocks(self, start_block: Optional[int] = None, end_block: Optional[int] = None):
        """Monitor blocks for events"""
        current_block = start_block if start_block else self.w3.eth.block_number
        
        print(f"\nStarting event monitoring from block {current_block}")
        print("Press Ctrl+C to stop\n")
        
        consecutive_errors = 0
        max_consecutive_errors = 5
        
        try:
            while True:
                try:
                    # Get latest block if we're in live mode
                    latest_block = self.w3.eth.block_number
                    
                    # If end_block is specified, don't go beyond it
                    if end_block and current_block > end_block:
                        print(f"\nReached end block {end_block}")
                        break
                    
                    # Process blocks up to latest
                    while current_block <= latest_block:
                        events = self.get_events_in_block(current_block)
                        
                        if events:
                            print(f"\n{'='*80}")
                            print(f"Found {len(events)} event(s) in block {current_block}")
                            print(f"{'='*80}")
                            
                            for event in events:
                                self.print_event(event)
                        else:
                            # Progress indicator every 100 blocks
                            if current_block % 100 == 0:
                                print(f"Processed up to block {current_block} (latest: {latest_block})")
                        
                        current_block += 1
                        
                        # If we have an end block, check if we're done
                        if end_block and current_block > end_block:
                            break
                    
                    # If no end block specified, wait for new blocks
                    if not end_block:
                        if current_block > latest_block:
                            print(f"Waiting for new blocks... (current: {latest_block})")
                            time.sleep(12)  # Ethereum block time
                    else:
                        break
                    
                    # Reset error counter on success
                    consecutive_errors = 0
                    
                except Exception as e:
                    consecutive_errors += 1
                    print(f"Error: {e}")
                    
                    if consecutive_errors >= max_consecutive_errors:
                        print(f"Too many consecutive errors ({consecutive_errors}), exiting...")
                        break
                    
                    print(f"Retrying in 5 seconds... (error {consecutive_errors}/{max_consecutive_errors})")
                    time.sleep(5)
                    
        except KeyboardInterrupt:
            print(f"\n\nStopped at block {current_block - 1}")

@click.command()
@click.option('--rpc-url', envvar='RPC_URL', required=True, help='Ethereum RPC URL')
@click.option('--inbox-address', envvar='INBOX_ADDRESS', required=True, help='TaikoInbox contract address')
@click.option('--start-block', envvar='START_BLOCK', type=int, help='Starting block number')
@click.option('--end-block', type=int, help='End block number (for historical processing)')
@click.option('--latest', is_flag=True, help='Start from latest block')
def main(rpc_url: str, inbox_address: str, start_block: Optional[int], end_block: Optional[int], latest: bool):
    """Taiko L1 Event Monitor - Step 1: Basic event subscription"""
    
    print("=== Taiko L1 Event Monitor (Step 1: Barebone) ===")
    print("This version subscribes to events and prints raw data\n")
    
    try:
        # Initialize monitor
        monitor = EventMonitor(rpc_url, inbox_address)
        
        # Determine starting block
        if latest:
            start_block = None  # Will use current block
        elif not start_block:
            # Ask user
            current = monitor.w3.eth.block_number
            print(f"\nCurrent block: {current}")
            print("Options:")
            print("1. Start from current block")
            print("2. Start from specific block")
            
            choice = input("\nYour choice (1-2): ")
            if choice == '2':
                start_block = int(input("Enter starting block number: "))
            else:
                start_block = current
        
        # Start monitoring
        monitor.monitor_blocks(start_block, end_block)
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()