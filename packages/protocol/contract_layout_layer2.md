## contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault

| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                           |
| ------------------ | ---------------------------------------------------- | ---- | ------ | ----- | -------------------------------------------------- |
| \_initialized      | uint8                                                | 0    | 0      | 1     | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_initializing     | bool                                                 | 0    | 1      | 1     | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[50]                                          | 1    | 0      | 1600  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_owner            | address                                              | 51   | 0      | 20    | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[49]                                          | 52   | 0      | 1568  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_pendingOwner     | address                                              | 101  | 0      | 20    | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[49]                                          | 102  | 0      | 1568  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| addressManager     | address                                              | 151  | 0      | 20    | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[49]                                          | 152  | 0      | 1568  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_reentry        | uint8                                                | 201  | 0      | 1     | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_paused         | uint8                                                | 201  | 1      | 1     | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| lastUnpausedAt     | uint64                                               | 201  | 2      | 8     | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[49]                                          | 202  | 0      | 1568  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[50]                                          | 251  | 0      | 1600  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| bridgedToCanonical | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[48]                                          | 303  | 0      | 1536  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[50]                                          | 351  | 0      | 1600  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[50]                                          | 401  | 0      | 1600  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap            | uint256[50]                                          | 451  | 0      | 1600  | contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault |

## contracts/tokenvault/ERC20Vault.sol:ERC20Vault

| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                       |
| ------------------ | ---------------------------------------------------- | ---- | ------ | ----- | ---------------------------------------------- |
| \_initialized      | uint8                                                | 0    | 0      | 1     | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_initializing     | bool                                                 | 0    | 1      | 1     | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[50]                                          | 1    | 0      | 1600  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_owner            | address                                              | 51   | 0      | 20    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[49]                                          | 52   | 0      | 1568  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_pendingOwner     | address                                              | 101  | 0      | 20    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[49]                                          | 102  | 0      | 1568  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| addressManager     | address                                              | 151  | 0      | 20    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[49]                                          | 152  | 0      | 1568  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_reentry        | uint8                                                | 201  | 0      | 1     | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_paused         | uint8                                                | 201  | 1      | 1     | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| lastUnpausedAt     | uint64                                               | 201  | 2      | 8     | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[49]                                          | 202  | 0      | 1568  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[50]                                          | 251  | 0      | 1600  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| bridgedToCanonical | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| btokenDenylist     | mapping(address => bool)                             | 303  | 0      | 32    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| lastMigrationStart | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap            | uint256[46]                                          | 305  | 0      | 1472  | contracts/tokenvault/ERC20Vault.sol:ERC20Vault |

## contracts/tokenvault/ERC721Vault.sol:ERC721Vault

| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                         |
| ------------------ | ---------------------------------------------------- | ---- | ------ | ----- | ------------------------------------------------ |
| \_initialized      | uint8                                                | 0    | 0      | 1     | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_initializing     | bool                                                 | 0    | 1      | 1     | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[50]                                          | 1    | 0      | 1600  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_owner            | address                                              | 51   | 0      | 20    | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[49]                                          | 52   | 0      | 1568  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_pendingOwner     | address                                              | 101  | 0      | 20    | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[49]                                          | 102  | 0      | 1568  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| addressManager     | address                                              | 151  | 0      | 20    | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[49]                                          | 152  | 0      | 1568  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_reentry        | uint8                                                | 201  | 0      | 1     | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_paused         | uint8                                                | 201  | 1      | 1     | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| lastUnpausedAt     | uint64                                               | 201  | 2      | 8     | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[49]                                          | 202  | 0      | 1568  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[50]                                          | 251  | 0      | 1600  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| bridgedToCanonical | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[48]                                          | 303  | 0      | 1536  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |
| \_\_gap            | uint256[50]                                          | 351  | 0      | 1600  | contracts/tokenvault/ERC721Vault.sol:ERC721Vault |

## contracts/tokenvault/BridgedERC20.sol:BridgedERC20

| Name             | Type                                            | Slot | Offset | Bytes | Contract                                           |
| ---------------- | ----------------------------------------------- | ---- | ------ | ----- | -------------------------------------------------- |
| \_initialized    | uint8                                           | 0    | 0      | 1     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_initializing   | bool                                            | 0    | 1      | 1     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[50]                                     | 1    | 0      | 1600  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_owner          | address                                         | 51   | 0      | 20    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[49]                                     | 52   | 0      | 1568  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_pendingOwner   | address                                         | 101  | 0      | 20    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[49]                                     | 102  | 0      | 1568  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| addressManager   | address                                         | 151  | 0      | 20    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[49]                                     | 152  | 0      | 1568  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_reentry      | uint8                                           | 201  | 0      | 1     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_paused       | uint8                                           | 201  | 1      | 1     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| lastUnpausedAt   | uint64                                          | 201  | 2      | 8     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[49]                                     | 202  | 0      | 1568  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_balances       | mapping(address => uint256)                     | 251  | 0      | 32    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_allowances     | mapping(address => mapping(address => uint256)) | 252  | 0      | 32    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_totalSupply    | uint256                                         | 253  | 0      | 32    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_name           | string                                          | 254  | 0      | 32    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_symbol         | string                                          | 255  | 0      | 32    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[45]                                     | 256  | 0      | 1440  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| srcToken         | address                                         | 301  | 0      | 20    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_srcDecimals  | uint8                                           | 301  | 20     | 1     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| srcChainId       | uint256                                         | 302  | 0      | 32    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| migratingAddress | address                                         | 303  | 0      | 20    | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| migratingInbound | bool                                            | 303  | 20     | 1     | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap          | uint256[47]                                     | 304  | 0      | 1504  | contracts/tokenvault/BridgedERC20.sol:BridgedERC20 |

## contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2

| Name             | Type                                                   | Slot | Offset | Bytes | Contract                                               |
| ---------------- | ------------------------------------------------------ | ---- | ------ | ----- | ------------------------------------------------------ |
| \_initialized    | uint8                                                  | 0    | 0      | 1     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_initializing   | bool                                                   | 0    | 1      | 1     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[50]                                            | 1    | 0      | 1600  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_owner          | address                                                | 51   | 0      | 20    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[49]                                            | 52   | 0      | 1568  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_pendingOwner   | address                                                | 101  | 0      | 20    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[49]                                            | 102  | 0      | 1568  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| addressManager   | address                                                | 151  | 0      | 20    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[49]                                            | 152  | 0      | 1568  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_reentry      | uint8                                                  | 201  | 0      | 1     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_paused       | uint8                                                  | 201  | 1      | 1     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| lastUnpausedAt   | uint64                                                 | 201  | 2      | 8     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[49]                                            | 202  | 0      | 1568  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_balances       | mapping(address => uint256)                            | 251  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_allowances     | mapping(address => mapping(address => uint256))        | 252  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_totalSupply    | uint256                                                | 253  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_name           | string                                                 | 254  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_symbol         | string                                                 | 255  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[45]                                            | 256  | 0      | 1440  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| srcToken         | address                                                | 301  | 0      | 20    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_srcDecimals  | uint8                                                  | 301  | 20     | 1     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| srcChainId       | uint256                                                | 302  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| migratingAddress | address                                                | 303  | 0      | 20    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| migratingInbound | bool                                                   | 303  | 20     | 1     | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[47]                                            | 304  | 0      | 1504  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_hashedName     | bytes32                                                | 351  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_hashedVersion  | bytes32                                                | 352  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_name           | string                                                 | 353  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_version        | string                                                 | 354  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[48]                                            | 355  | 0      | 1536  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_nonces         | mapping(address => struct CountersUpgradeable.Counter) | 403  | 0      | 32    | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap          | uint256[49]                                            | 404  | 0      | 1568  | contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |

## contracts/tokenvault/BridgedERC721.sol:BridgedERC721
