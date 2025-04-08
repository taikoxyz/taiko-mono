# pip install web3 tqdm
import csv
from web3 import Web3
from tqdm import tqdm
import time
import os

# === Config ===
NODE_URL = "https://rpc.mainnet.taiko.xyz"  # Replace with your node URL
NODE_URL = "https://taiko-rpc.publicnode.com" 
NODE_URL = "https://taiko-mainnet.gateway.tenderly.co" 
NODE_URL = "https://https://rpc.taiko.tools" 
BLOCK_COUNT = 10000

# === Connect ===
w3 = Web3(Web3.HTTPProvider(NODE_URL))
if not w3.is_connected():
    raise Exception("Web3 connection failed")

# === Get latest block number ===
latest_block = w3.eth.block_number
start_block = latest_block - BLOCK_COUNT + 1
output_file = "taiko_block_data.csv"

# === Read existing data ===
existing_blocks = {}
if os.path.exists(output_file):
    with open(output_file, mode="r", newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            existing_blocks[int(row["block_number"])] = {
                "timestamp": int(row["timestamp"]),
                "gas_limit": int(row["gas_limit"]),
                "gas_used": int(row["gas_used"]),
                "base_fee_per_gas": int(row["base_fee_per_gas"])
            }

# === Write CSV ===
print(f"Fetching blocks from {start_block} to {latest_block} from {NODE_URL}...")
with open(output_file, mode="w", newline="") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["block_number", "timestamp", "gas_limit", "gas_used", "base_fee_per_gas"])

    for block_number in tqdm(range(start_block, latest_block + 1)):
        if block_number not in existing_blocks:
            block = w3.eth.get_block(block_number)
            base_fee = block.get("baseFeePerGas", 0)
            writer.writerow([
                block.number,
                block.timestamp,
                block.gasLimit,
                block.gasUsed,
                base_fee
            ])
            time.sleep(0.05)  # Wait for 10 ms before the next call
        else:
            writer.writerow([
                block_number,
                existing_blocks[block_number]["timestamp"],
                existing_blocks[block_number]["gas_limit"],
                existing_blocks[block_number]["gas_used"],
                existing_blocks[block_number]["base_fee_per_gas"]
            ])
print(f"Done. Saved to {output_file}")