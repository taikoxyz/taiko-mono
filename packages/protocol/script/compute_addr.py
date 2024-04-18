import os
import multiprocessing
from web3 import Web3

def compute_create2_address(deployer_address, salt, keccak256_bytecode):
    deployer_address_bytes = Web3.to_bytes(hexstr=deployer_address)
    salt_bytes = Web3.to_bytes(hexstr=salt)
    bytecode_hash_bytes = Web3.to_bytes(hexstr=keccak256_bytecode)
    combined = b'\xff' + deployer_address_bytes + salt_bytes + bytecode_hash_bytes
    address_hash = Web3.keccak(combined)
    return '0x' + address_hash[-20:].hex()

def load_state(file_path):
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            data = file.read().split(',')
            return data[0], data[1]
    return '0xffffffffffffffffffffffffffffffffffffffff', '0x0'  # Default to highest possible address and zero salt

def save_state(file_path, salt, address):
    with open(file_path, 'w') as file:
        file.write(f"{salt},{address}")

def find_smallest_address(deployer_address, keccak256_bytecode, shared_state, lock, range_start, range_end):
    print(f"Process {os.getpid()} starting from {range_start} to {range_end}")  # Diagnostic print
    current_salt = range_start
    count = 0  # Add a counter to periodically report progress
    while current_salt < range_end:
        salt_hex = Web3.to_hex(current_salt)
        new_address = compute_create2_address(deployer_address, salt_hex, keccak256_bytecode)
        if count % 100000 == 0:  # Report every 100000 iterations
            print(f"Process {os.getpid()}: current salt {salt_hex}, current smallest: {shared_state[0]}")
        with lock:
            smallest_address, smallest_salt = shared_state[0], shared_state[1]
            if new_address < smallest_address:
                shared_state[0] = new_address
                shared_state[1] = salt_hex
                print(f"Process {os.getpid()}: New smallest address: {new_address} with salt {salt_hex}")
        current_salt += 1
        count += 1


def main():
    deployer_address = '0x1234567890123456789012345678901234567890'
    keccak256_bytecode = '0xd1d346dd74f52e9a2b7590b717f82d7a9ccaff0705acda80552d3e3a5f3b8f03'
    file_path = keccak256_bytecode[0:10] + ".txt"

    num_processes = multiprocessing.cpu_count()
    manager = multiprocessing.Manager()
    shared_state = manager.list(load_state(file_path))  # Load initial state or default
    lock = manager.Lock()

    processes = []
    salt_range = 2**24  # Smaller salt range for faster processing
    salt_start = 0

    for i in range(num_processes):
        process_range_start = salt_start + i * salt_range
        process_range_end = process_range_start + salt_range
        process = multiprocessing.Process(target=find_smallest_address, args=(deployer_address, keccak256_bytecode, shared_state, lock, process_range_start, process_range_end))
        processes.append(process)
        process.start()

    for process in processes:
        process.join()

    # Save the final state once all processes have finished
    save_state(file_path, shared_state[1], shared_state[0])

if __name__ == "__main__":
    main()
