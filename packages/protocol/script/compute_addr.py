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
            return int(data[0], 16), data[1]
    return None, '0x0'

def save_state(file_path, salt, address, lock):
    with lock:
        with open(file_path, 'w') as file:
            file.write(f"{salt},{address}")

def find_smallest_address(deployer_address, keccak256_bytecode, file_path, lock, range_start, range_end):
    initial_salt, smallest_address = load_state(file_path)

    current_salt = range_start
    while current_salt < range_end:
        salt_hex = Web3.to_hex(current_salt)
        new_address = compute_create2_address(deployer_address, salt_hex, keccak256_bytecode)
        if smallest_address == '0x0' or new_address < smallest_address:
            smallest_address = new_address
            save_state(file_path, salt_hex, smallest_address, lock)
            print(f"Thread {os.getpid()}: New smallest address: {smallest_address} with salt {salt_hex}")
        current_salt += 1

def main():
    deployer_address = '0x1234567890123456789012345678901234567890'

    keccak256_bytecode = '0xd1d246dd74f52e9a2b7590b717f82d7a9ccaff0705acda80552d3e3a5f3b8f03'

    file_path = keccak256_bytecode[0:10] + ".txt"
    num_processes = multiprocessing.cpu_count()

    # Creating a lock for file operations
    lock = multiprocessing.Lock()

    # Calculate the range of salts each process will handle
    salt_start = 0
    salt_range = 2**64 // num_processes

    processes = []
    for i in range(num_processes):
        process_range_start = salt_start + i * salt_range
        process_range_end = process_range_start + salt_range
        process = multiprocessing.Process(target=find_smallest_address, args=(deployer_address, keccak256_bytecode, file_path, lock, process_range_start, process_range_end))
        processes.append(process)
        process.start()

    for process in processes:
        process.join()

if __name__ == "__main__":
    main()
