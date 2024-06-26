import requests
import json
import argparse

# Set up argument parser
parser = argparse.ArgumentParser(description="Send JSON-RPC requests to a specified method and port.")
parser.add_argument("method", type=str, help="The RPC method to call.")
parser.add_argument("port", type=int, help="The port to use for the RPC server.")
args = parser.parse_args()

# Define the URL of the JSON-RPC server
url = f"http://localhost:{args.port}/rpc"

# Define the headers
headers = {
    "Content-Type": "application/json",
}

# Define the payload for the specified method
payload = {
    "jsonrpc": "2.0",
    "method": args.method,
    "params": {
        "TxLists": [
            [
                {
                    "type": "0x0",
                    "chainId": "0x28c61",
                    "nonce": "0x1",
                    "to": "0xbfadd5365bb2890ad832038837115e60b71f7cbb",
                    "gas": "0x267ac",
                    "gasPrice": "0x5e76e0800",

                    "value": "0x0",
                    "input": "0x40d097c30000000000000000000000004cea2c7d358e313f5d0287c475f9ae943fe1a913",
                    "v": "0x518e6",
                    "r": "0xb22da5cdc4c091ec85d2dda9054aa497088e55bd9f0335f39864ae1c598dd35",
                    "s": "0x6eee1bcfe6a1855e89dd23d40942c90a036f273159b4c4fd217d58169493f055",
                    "hash": "0x7c76b9906579e54df54fe77ad1706c47aca706b3eb5cfd8a30ccc3c5a19e8ecd"
                }
            ]
        ], "gasUsed": 102
    },
    "id": 1,
}

# Print the payload for verification
print("Payload:", json.dumps(payload, indent=4))

# Send the request
response = requests.post(url, headers=headers, data=json.dumps(payload))
print(f"Response: {response.text}")

if response.status_code != 200:
    print(f"Error: {response.status_code}")
else:
    print("Request was successful.")

print(str(response))
