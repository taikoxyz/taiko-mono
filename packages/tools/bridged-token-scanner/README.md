# bridged-token-scanner

This script extracts `BridgedTokenDeployed` events from Taiko's bridge vault contracts (ERC20, ERC721, ERC1155) across different networks and exports them into structured JSON and CSV files.

## Features

- Supports all vault types: **ERC20**, **ERC721**, **ERC1155**
- Queries logs from the blockchain using `ethers.js`
- Outputs results in:
  - JSON per chunk (e.g., `chunk_1528000_1528099_BridgedTokenDeployed.json`)
  - CSV per chunk
  - Combined full JSON and CSV per network
- Organizes output by network and vault type

## Setup

### Prerequisites

- Node.js v22+
- Install dependencies:

```bash
nvm use 22
npm install ethers
```

### Project Structure

```
.
├── index.js               # Main event extraction script
├── networks.js            # Network and contract address configuration
├── utils.js               # Utility functions (JSON/CSV saving, block discovery)
├── data/                  # Output directory for event files
└── README.md              # This file
```

## Configuration

Update `networks.js` to define:

- RPC URL per network
- Vault contract addresses for ERC20, ERC721, ERC1155
- Optional: `fromBlock` and `toBlock`

## Usage

```bash
node index.js
```

- This script will:

  - Connect to each defined network
  - Fetch `BridgedTokenDeployed` events in block chunks
  - Save results into `./data/<Network>/<VaultType>/`

## Output Example

```
data/
├── L1_Testnet_Holesky/
│   ├── BridgedTokenDeployed_ERC20/
│   │   ├── chunk_1528000_1528099_BridgedTokenDeployed.json
│   │   └── chunk_1528000_1528099_BridgedTokenDeployed.csv
│   └── BridgedTokenDeployed_ERC20.json
├── L2_Testnet_Taiko/
│   └── BridgedTokenDeployed_ERC721/...
```
