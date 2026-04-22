import json
import sys
import time

# Taiko Labs Wallet (on Taiko): 0x7aEeed56d1B21baD7b66f1357A6Ed51DA848a698
#:Token Bridged USDC (Stargate) 0x19e26B0638bf63aa9fa4d14c6baF8D52eBE86C5C (DECIMAL 6)
def generate_json(input_file_path, safe_address, token_address, decimals):
    transactions = []
    multiplier = 10 ** decimals
    total_amount = 0
    num_recipients = 0

    with open(input_file_path, mode='r') as file:
        for line in file:
            parts = line.strip().split()
            if len(parts) != 2:
                print(f"Invalid line format: {line}")
                continue
            recipient = parts[0]
            amount = int(parts[1]) * multiplier
            total_amount += amount
            num_recipients += 1

            print(f"Recipient: {recipient}, Amount: {amount}")

            transactions.append({
                "to": token_address,
                "value": "0",
                "data": None,
                "contractMethod": {
                    "inputs": [
                        {
                            "internalType": "address",
                            "name": "to",
                            "type": "address"
                        },
                        {
                            "internalType": "uint256",
                            "name": "amount",
                            "type": "uint256"
                        }
                    ],
                    "name": "transfer",
                    "payable": False
                },
                "contractInputsValues": {
                    "to": recipient,
                    "amount": str(amount)
                }
            })

    print(f"Number of Recipients: {num_recipients}")
    print(f"Total Token Amount: {total_amount}")

    result = {
        "version": "1.0",
        "chainId": "167000",
        "createdAt": int(time.time()),
        "meta": {
            "name": "Transactions Batch",
            "description": "",
            "txBuilderVersion": "1.16.5",
            "createdFromSafeAddress": safe_address
        },
        "transactions": transactions
    }

    print("safe_batch_transfers.json created")
    with open("safe_batch_transfers.json", 'w') as json_file:
        json.dump(result, json_file, indent=4)

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python3 safe_batch_transfer.py <input_file> <safe_address> <token_address> <decimals>")
        sys.exit(1)

    input_file_path = sys.argv[1]
    print(f"input file: {input_file_path}")

    safe_address = sys.argv[2]
    print(f"safe address: {safe_address}")

    token_address = sys.argv[3]
    print(f"token address: {token_address}")

    decimals = int(sys.argv[4])
    print(f"decimals: {decimals}")

    generate_json(input_file_path, safe_address, token_address, decimals)
