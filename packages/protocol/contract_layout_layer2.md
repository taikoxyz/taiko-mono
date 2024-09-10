## contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault
| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                                  |
|--------------------|------------------------------------------------------|------|--------|-------|-----------------------------------------------------------|
| _initialized       | uint8                                                | 0    | 0      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| _initializing      | bool                                                 | 0    | 1      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[50]                                          | 1    | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| _owner             | address                                              | 51   | 0      | 20    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[49]                                          | 52   | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| _pendingOwner      | address                                              | 101  | 0      | 20    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[49]                                          | 102  | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| addressManager     | address                                              | 151  | 0      | 20    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[49]                                          | 152  | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __reentry          | uint8                                                | 201  | 0      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __paused           | uint8                                                | 201  | 1      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| lastUnpausedAt     | uint64                                               | 201  | 2      | 8     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[49]                                          | 202  | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[50]                                          | 251  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| bridgedToCanonical | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[48]                                          | 303  | 0      | 1536  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[50]                                          | 351  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[50]                                          | 401  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| __gap              | uint256[50]                                          | 451  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |

## contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault
| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                              |
|--------------------|------------------------------------------------------|------|--------|-------|-------------------------------------------------------|
| _initialized       | uint8                                                | 0    | 0      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| _initializing      | bool                                                 | 0    | 1      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[50]                                          | 1    | 0      | 1600  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| _owner             | address                                              | 51   | 0      | 20    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[49]                                          | 52   | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| _pendingOwner      | address                                              | 101  | 0      | 20    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[49]                                          | 102  | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| addressManager     | address                                              | 151  | 0      | 20    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[49]                                          | 152  | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __reentry          | uint8                                                | 201  | 0      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __paused           | uint8                                                | 201  | 1      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| lastUnpausedAt     | uint64                                               | 201  | 2      | 8     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[49]                                          | 202  | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[50]                                          | 251  | 0      | 1600  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| bridgedToCanonical | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| btokenDenylist     | mapping(address => bool)                             | 303  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| lastMigrationStart | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| __gap              | uint256[46]                                          | 305  | 0      | 1472  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |

## contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault
| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                                |
|--------------------|------------------------------------------------------|------|--------|-------|---------------------------------------------------------|
| _initialized       | uint8                                                | 0    | 0      | 1     | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| _initializing      | bool                                                 | 0    | 1      | 1     | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[50]                                          | 1    | 0      | 1600  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| _owner             | address                                              | 51   | 0      | 20    | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[49]                                          | 52   | 0      | 1568  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| _pendingOwner      | address                                              | 101  | 0      | 20    | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[49]                                          | 102  | 0      | 1568  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| addressManager     | address                                              | 151  | 0      | 20    | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[49]                                          | 152  | 0      | 1568  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __reentry          | uint8                                                | 201  | 0      | 1     | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __paused           | uint8                                                | 201  | 1      | 1     | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| lastUnpausedAt     | uint64                                               | 201  | 2      | 8     | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[49]                                          | 202  | 0      | 1568  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[50]                                          | 251  | 0      | 1600  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| bridgedToCanonical | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[48]                                          | 303  | 0      | 1536  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |
| __gap              | uint256[50]                                          | 351  | 0      | 1600  | contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault |

## contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20
| Name             | Type                                            | Slot | Offset | Bytes | Contract                                                  |
|------------------|-------------------------------------------------|------|--------|-------|-----------------------------------------------------------|
| _initialized     | uint8                                           | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _initializing    | bool                                            | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[50]                                     | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _owner           | address                                         | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[49]                                     | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _pendingOwner    | address                                         | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[49]                                     | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| addressManager   | address                                         | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[49]                                     | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __reentry        | uint8                                           | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __paused         | uint8                                           | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| lastUnpausedAt   | uint64                                          | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[49]                                     | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _balances        | mapping(address => uint256)                     | 251  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _allowances      | mapping(address => mapping(address => uint256)) | 252  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _totalSupply     | uint256                                         | 253  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _name            | string                                          | 254  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| _symbol          | string                                          | 255  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[45]                                     | 256  | 0      | 1440  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| srcToken         | address                                         | 301  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __srcDecimals    | uint8                                           | 301  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| srcChainId       | uint256                                         | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| migratingAddress | address                                         | 303  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| migratingInbound | bool                                            | 303  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| __gap            | uint256[47]                                     | 304  | 0      | 1504  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |

## contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2
| Name             | Type                                                   | Slot | Offset | Bytes | Contract                                                      |
|------------------|--------------------------------------------------------|------|--------|-------|---------------------------------------------------------------|
| _initialized     | uint8                                                  | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _initializing    | bool                                                   | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[50]                                            | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _owner           | address                                                | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[49]                                            | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _pendingOwner    | address                                                | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[49]                                            | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| addressManager   | address                                                | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[49]                                            | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __reentry        | uint8                                                  | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __paused         | uint8                                                  | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| lastUnpausedAt   | uint64                                                 | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[49]                                            | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _balances        | mapping(address => uint256)                            | 251  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _allowances      | mapping(address => mapping(address => uint256))        | 252  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _totalSupply     | uint256                                                | 253  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _name            | string                                                 | 254  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _symbol          | string                                                 | 255  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[45]                                            | 256  | 0      | 1440  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| srcToken         | address                                                | 301  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __srcDecimals    | uint8                                                  | 301  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| srcChainId       | uint256                                                | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| migratingAddress | address                                                | 303  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| migratingInbound | bool                                                   | 303  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[47]                                            | 304  | 0      | 1504  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _hashedName      | bytes32                                                | 351  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _hashedVersion   | bytes32                                                | 352  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _name            | string                                                 | 353  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _version         | string                                                 | 354  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[48]                                            | 355  | 0      | 1536  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| _nonces          | mapping(address => struct CountersUpgradeable.Counter) | 403  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| __gap            | uint256[49]                                            | 404  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |

## contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721
| Name               | Type                                         | Slot | Offset | Bytes | Contract                                                    |
|--------------------|----------------------------------------------|------|--------|-------|-------------------------------------------------------------|
| _initialized       | uint8                                        | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _initializing      | bool                                         | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[50]                                  | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _owner             | address                                      | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[49]                                  | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _pendingOwner      | address                                      | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[49]                                  | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| addressManager     | address                                      | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[49]                                  | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __reentry          | uint8                                        | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __paused           | uint8                                        | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| lastUnpausedAt     | uint64                                       | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[49]                                  | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[50]                                  | 251  | 0      | 1600  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _name              | string                                       | 301  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _symbol            | string                                       | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _owners            | mapping(uint256 => address)                  | 303  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _balances          | mapping(address => uint256)                  | 304  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _tokenApprovals    | mapping(uint256 => address)                  | 305  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| _operatorApprovals | mapping(address => mapping(address => bool)) | 306  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[44]                                  | 307  | 0      | 1408  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| srcToken           | address                                      | 351  | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| srcChainId         | uint256                                      | 352  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| __gap              | uint256[48]                                  | 353  | 0      | 1536  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |

## contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155
| Name               | Type                                            | Slot | Offset | Bytes | Contract                                                      |
|--------------------|-------------------------------------------------|------|--------|-------|---------------------------------------------------------------|
| _initialized       | uint8                                           | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| _initializing      | bool                                            | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[50]                                     | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| _owner             | address                                         | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[49]                                     | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| _pendingOwner      | address                                         | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[49]                                     | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| addressManager     | address                                         | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[49]                                     | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __reentry          | uint8                                           | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __paused           | uint8                                           | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| lastUnpausedAt     | uint64                                          | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[49]                                     | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[50]                                     | 251  | 0      | 1600  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| _balances          | mapping(uint256 => mapping(address => uint256)) | 301  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| _operatorApprovals | mapping(address => mapping(address => bool))    | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| _uri               | string                                          | 303  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[47]                                     | 304  | 0      | 1504  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| srcToken           | address                                         | 351  | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| srcChainId         | uint256                                         | 352  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| symbol             | string                                          | 353  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| name               | string                                          | 354  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| __gap              | uint256[46]                                     | 355  | 0      | 1472  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |

## contracts/shared/bridge/Bridge.sol:Bridge
| Name           | Type                                    | Slot | Offset | Bytes | Contract                                  |
|----------------|-----------------------------------------|------|--------|-------|-------------------------------------------|
| _initialized   | uint8                                   | 0    | 0      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| _initializing  | bool                                    | 0    | 1      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| __gap          | uint256[50]                             | 1    | 0      | 1600  | contracts/shared/bridge/Bridge.sol:Bridge |
| _owner         | address                                 | 51   | 0      | 20    | contracts/shared/bridge/Bridge.sol:Bridge |
| __gap          | uint256[49]                             | 52   | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| _pendingOwner  | address                                 | 101  | 0      | 20    | contracts/shared/bridge/Bridge.sol:Bridge |
| __gap          | uint256[49]                             | 102  | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| addressManager | address                                 | 151  | 0      | 20    | contracts/shared/bridge/Bridge.sol:Bridge |
| __gap          | uint256[49]                             | 152  | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| __reentry      | uint8                                   | 201  | 0      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| __paused       | uint8                                   | 201  | 1      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| lastUnpausedAt | uint64                                  | 201  | 2      | 8     | contracts/shared/bridge/Bridge.sol:Bridge |
| __gap          | uint256[49]                             | 202  | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| __reserved1    | uint64                                  | 251  | 0      | 8     | contracts/shared/bridge/Bridge.sol:Bridge |
| nextMessageId  | uint64                                  | 251  | 8      | 8     | contracts/shared/bridge/Bridge.sol:Bridge |
| messageStatus  | mapping(bytes32 => enum IBridge.Status) | 252  | 0      | 32    | contracts/shared/bridge/Bridge.sol:Bridge |
| __ctx          | struct IBridge.Context                  | 253  | 0      | 64    | contracts/shared/bridge/Bridge.sol:Bridge |
| __reserved2    | uint256                                 | 255  | 0      | 32    | contracts/shared/bridge/Bridge.sol:Bridge |
| __reserved3    | uint256                                 | 256  | 0      | 32    | contracts/shared/bridge/Bridge.sol:Bridge |
| __gap          | uint256[44]                             | 257  | 0      | 1408  | contracts/shared/bridge/Bridge.sol:Bridge |

## contracts/shared/bridge/QuotaManager.sol:QuotaManager
| Name           | Type                                          | Slot | Offset | Bytes | Contract                                              |
|----------------|-----------------------------------------------|------|--------|-------|-------------------------------------------------------|
| _initialized   | uint8                                         | 0    | 0      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| _initializing  | bool                                          | 0    | 1      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __gap          | uint256[50]                                   | 1    | 0      | 1600  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| _owner         | address                                       | 51   | 0      | 20    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __gap          | uint256[49]                                   | 52   | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| _pendingOwner  | address                                       | 101  | 0      | 20    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __gap          | uint256[49]                                   | 102  | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| addressManager | address                                       | 151  | 0      | 20    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __gap          | uint256[49]                                   | 152  | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __reentry      | uint8                                         | 201  | 0      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __paused       | uint8                                         | 201  | 1      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| lastUnpausedAt | uint64                                        | 201  | 2      | 8     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __gap          | uint256[49]                                   | 202  | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| tokenQuota     | mapping(address => struct QuotaManager.Quota) | 251  | 0      | 32    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| quotaPeriod    | uint24                                        | 252  | 0      | 3     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| __gap          | uint256[48]                                   | 253  | 0      | 1536  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |

## contracts/shared/common/AddressManager.sol:AddressManager
| Name           | Type                                            | Slot | Offset | Bytes | Contract                                                  |
|----------------|-------------------------------------------------|------|--------|-------|-----------------------------------------------------------|
| _initialized   | uint8                                           | 0    | 0      | 1     | contracts/shared/common/AddressManager.sol:AddressManager |
| _initializing  | bool                                            | 0    | 1      | 1     | contracts/shared/common/AddressManager.sol:AddressManager |
| __gap          | uint256[50]                                     | 1    | 0      | 1600  | contracts/shared/common/AddressManager.sol:AddressManager |
| _owner         | address                                         | 51   | 0      | 20    | contracts/shared/common/AddressManager.sol:AddressManager |
| __gap          | uint256[49]                                     | 52   | 0      | 1568  | contracts/shared/common/AddressManager.sol:AddressManager |
| _pendingOwner  | address                                         | 101  | 0      | 20    | contracts/shared/common/AddressManager.sol:AddressManager |
| __gap          | uint256[49]                                     | 102  | 0      | 1568  | contracts/shared/common/AddressManager.sol:AddressManager |
| addressManager | address                                         | 151  | 0      | 20    | contracts/shared/common/AddressManager.sol:AddressManager |
| __gap          | uint256[49]                                     | 152  | 0      | 1568  | contracts/shared/common/AddressManager.sol:AddressManager |
| __reentry      | uint8                                           | 201  | 0      | 1     | contracts/shared/common/AddressManager.sol:AddressManager |
| __paused       | uint8                                           | 201  | 1      | 1     | contracts/shared/common/AddressManager.sol:AddressManager |
| lastUnpausedAt | uint64                                          | 201  | 2      | 8     | contracts/shared/common/AddressManager.sol:AddressManager |
| __gap          | uint256[49]                                     | 202  | 0      | 1568  | contracts/shared/common/AddressManager.sol:AddressManager |
| __addresses    | mapping(uint256 => mapping(bytes32 => address)) | 251  | 0      | 32    | contracts/shared/common/AddressManager.sol:AddressManager |
| __gap          | uint256[49]                                     | 252  | 0      | 1568  | contracts/shared/common/AddressManager.sol:AddressManager |

## contracts/shared/common/AddressResolver.sol:AddressResolver
| Name           | Type        | Slot | Offset | Bytes | Contract                                                    |
|----------------|-------------|------|--------|-------|-------------------------------------------------------------|
| _initialized   | uint8       | 0    | 0      | 1     | contracts/shared/common/AddressResolver.sol:AddressResolver |
| _initializing  | bool        | 0    | 1      | 1     | contracts/shared/common/AddressResolver.sol:AddressResolver |
| addressManager | address     | 0    | 2      | 20    | contracts/shared/common/AddressResolver.sol:AddressResolver |
| __gap          | uint256[49] | 1    | 0      | 1568  | contracts/shared/common/AddressResolver.sol:AddressResolver |

## contracts/shared/common/EssentialContract.sol:EssentialContract
| Name           | Type        | Slot | Offset | Bytes | Contract                                                        |
|----------------|-------------|------|--------|-------|-----------------------------------------------------------------|
| _initialized   | uint8       | 0    | 0      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| _initializing  | bool        | 0    | 1      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __gap          | uint256[50] | 1    | 0      | 1600  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| _owner         | address     | 51   | 0      | 20    | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __gap          | uint256[49] | 52   | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| _pendingOwner  | address     | 101  | 0      | 20    | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __gap          | uint256[49] | 102  | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| addressManager | address     | 151  | 0      | 20    | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __gap          | uint256[49] | 152  | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __reentry      | uint8       | 201  | 0      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __paused       | uint8       | 201  | 1      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| lastUnpausedAt | uint64      | 201  | 2      | 8     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| __gap          | uint256[49] | 202  | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |

## contracts/shared/signal/SignalService.sol:SignalService
| Name           | Type                                          | Slot | Offset | Bytes | Contract                                                |
|----------------|-----------------------------------------------|------|--------|-------|---------------------------------------------------------|
| _initialized   | uint8                                         | 0    | 0      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| _initializing  | bool                                          | 0    | 1      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| __gap          | uint256[50]                                   | 1    | 0      | 1600  | contracts/shared/signal/SignalService.sol:SignalService |
| _owner         | address                                       | 51   | 0      | 20    | contracts/shared/signal/SignalService.sol:SignalService |
| __gap          | uint256[49]                                   | 52   | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| _pendingOwner  | address                                       | 101  | 0      | 20    | contracts/shared/signal/SignalService.sol:SignalService |
| __gap          | uint256[49]                                   | 102  | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| addressManager | address                                       | 151  | 0      | 20    | contracts/shared/signal/SignalService.sol:SignalService |
| __gap          | uint256[49]                                   | 152  | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| __reentry      | uint8                                         | 201  | 0      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| __paused       | uint8                                         | 201  | 1      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| lastUnpausedAt | uint64                                        | 201  | 2      | 8     | contracts/shared/signal/SignalService.sol:SignalService |
| __gap          | uint256[49]                                   | 202  | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| topBlockId     | mapping(uint64 => mapping(bytes32 => uint64)) | 251  | 0      | 32    | contracts/shared/signal/SignalService.sol:SignalService |
| isAuthorized   | mapping(address => bool)                      | 252  | 0      | 32    | contracts/shared/signal/SignalService.sol:SignalService |
| __gap          | uint256[48]                                   | 253  | 0      | 1536  | contracts/shared/signal/SignalService.sol:SignalService |

## contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken
| Name                                                | Type                                                          | Slot | Offset | Bytes | Contract                                                       |
|-----------------------------------------------------|---------------------------------------------------------------|------|--------|-------|----------------------------------------------------------------|
| _initialized                                        | uint8                                                         | 0    | 0      | 1     | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _initializing                                       | bool                                                          | 0    | 1      | 1     | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[50]                                                   | 1    | 0      | 1600  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _owner                                              | address                                                       | 51   | 0      | 20    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 52   | 0      | 1568  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _pendingOwner                                       | address                                                       | 101  | 0      | 20    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 102  | 0      | 1568  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| addressManager                                      | address                                                       | 151  | 0      | 20    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 152  | 0      | 1568  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __reentry                                           | uint8                                                         | 201  | 0      | 1     | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __paused                                            | uint8                                                         | 201  | 1      | 1     | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| lastUnpausedAt                                      | uint64                                                        | 201  | 2      | 8     | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 202  | 0      | 1568  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __slots_previously_used_by_ERC20SnapshotUpgradeable | uint256[50]                                                   | 251  | 0      | 1600  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _balances                                           | mapping(address => uint256)                                   | 301  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _allowances                                         | mapping(address => mapping(address => uint256))               | 302  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _totalSupply                                        | uint256                                                       | 303  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _name                                               | string                                                        | 304  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _symbol                                             | string                                                        | 305  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[45]                                                   | 306  | 0      | 1440  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _hashedName                                         | bytes32                                                       | 351  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _hashedVersion                                      | bytes32                                                       | 352  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _name                                               | string                                                        | 353  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _version                                            | string                                                        | 354  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[48]                                                   | 355  | 0      | 1536  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _nonces                                             | mapping(address => struct CountersUpgradeable.Counter)        | 403  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _PERMIT_TYPEHASH_DEPRECATED_SLOT                    | bytes32                                                       | 404  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 405  | 0      | 1568  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _delegates                                          | mapping(address => address)                                   | 454  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _checkpoints                                        | mapping(address => struct ERC20VotesUpgradeable.Checkpoint[]) | 455  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| _totalSupplyCheckpoints                             | struct ERC20VotesUpgradeable.Checkpoint[]                     | 456  | 0      | 32    | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[47]                                                   | 457  | 0      | 1504  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |
| __gap                                               | uint256[50]                                                   | 504  | 0      | 1600  | contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken |

## contracts/layer2/DelegateOwner.sol:DelegateOwner
| Name           | Type        | Slot | Offset | Bytes | Contract                                         |
|----------------|-------------|------|--------|-------|--------------------------------------------------|
| _initialized   | uint8       | 0    | 0      | 1     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| _initializing  | bool        | 0    | 1      | 1     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __gap          | uint256[50] | 1    | 0      | 1600  | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| _owner         | address     | 51   | 0      | 20    | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __gap          | uint256[49] | 52   | 0      | 1568  | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| _pendingOwner  | address     | 101  | 0      | 20    | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __gap          | uint256[49] | 102  | 0      | 1568  | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| addressManager | address     | 151  | 0      | 20    | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __gap          | uint256[49] | 152  | 0      | 1568  | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __reentry      | uint8       | 201  | 0      | 1     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __paused       | uint8       | 201  | 1      | 1     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| lastUnpausedAt | uint64      | 201  | 2      | 8     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __gap          | uint256[49] | 202  | 0      | 1568  | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| remoteChainId  | uint64      | 251  | 0      | 8     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| admin          | address     | 251  | 8      | 20    | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| nextTxId       | uint64      | 252  | 0      | 8     | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| remoteOwner    | address     | 252  | 8      | 20    | contracts/layer2/DelegateOwner.sol:DelegateOwner |
| __gap          | uint256[48] | 253  | 0      | 1536  | contracts/layer2/DelegateOwner.sol:DelegateOwner |

## contracts/layer2/based/TaikoL2.sol:TaikoL2
| Name            | Type                        | Slot | Offset | Bytes | Contract                                   |
|-----------------|-----------------------------|------|--------|-------|--------------------------------------------|
| _initialized    | uint8                       | 0    | 0      | 1     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| _initializing   | bool                        | 0    | 1      | 1     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __gap           | uint256[50]                 | 1    | 0      | 1600  | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| _owner          | address                     | 51   | 0      | 20    | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __gap           | uint256[49]                 | 52   | 0      | 1568  | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| _pendingOwner   | address                     | 101  | 0      | 20    | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __gap           | uint256[49]                 | 102  | 0      | 1568  | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| addressManager  | address                     | 151  | 0      | 20    | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __gap           | uint256[49]                 | 152  | 0      | 1568  | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __reentry       | uint8                       | 201  | 0      | 1     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __paused        | uint8                       | 201  | 1      | 1     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| lastUnpausedAt  | uint64                      | 201  | 2      | 8     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __gap           | uint256[49]                 | 202  | 0      | 1568  | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| _blockhashes    | mapping(uint256 => bytes32) | 251  | 0      | 32    | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| publicInputHash | bytes32                     | 252  | 0      | 32    | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| parentGasExcess | uint64                      | 253  | 0      | 8     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| lastSyncedBlock | uint64                      | 253  | 8      | 8     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| parentTimestamp | uint64                      | 253  | 16     | 8     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| parentGasTarget | uint64                      | 253  | 24     | 8     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| l1ChainId       | uint64                      | 254  | 0      | 8     | contracts/layer2/based/TaikoL2.sol:TaikoL2 |
| __gap           | uint256[46]                 | 255  | 0      | 1472  | contracts/layer2/based/TaikoL2.sol:TaikoL2 |

## contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2
| Name            | Type                        | Slot | Offset | Bytes | Contract                                             |
|-----------------|-----------------------------|------|--------|-------|------------------------------------------------------|
| _initialized    | uint8                       | 0    | 0      | 1     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| _initializing   | bool                        | 0    | 1      | 1     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __gap           | uint256[50]                 | 1    | 0      | 1600  | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| _owner          | address                     | 51   | 0      | 20    | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __gap           | uint256[49]                 | 52   | 0      | 1568  | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| _pendingOwner   | address                     | 101  | 0      | 20    | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __gap           | uint256[49]                 | 102  | 0      | 1568  | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| addressManager  | address                     | 151  | 0      | 20    | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __gap           | uint256[49]                 | 152  | 0      | 1568  | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __reentry       | uint8                       | 201  | 0      | 1     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __paused        | uint8                       | 201  | 1      | 1     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| lastUnpausedAt  | uint64                      | 201  | 2      | 8     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __gap           | uint256[49]                 | 202  | 0      | 1568  | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| _blockhashes    | mapping(uint256 => bytes32) | 251  | 0      | 32    | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| publicInputHash | bytes32                     | 252  | 0      | 32    | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| parentGasExcess | uint64                      | 253  | 0      | 8     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| lastSyncedBlock | uint64                      | 253  | 8      | 8     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| parentTimestamp | uint64                      | 253  | 16     | 8     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| parentGasTarget | uint64                      | 253  | 24     | 8     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| l1ChainId       | uint64                      | 254  | 0      | 8     | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |
| __gap           | uint256[46]                 | 255  | 0      | 1472  | contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2 |

## contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2
| Name            | Type                        | Slot | Offset | Bytes | Contract                                                   |
|-----------------|-----------------------------|------|--------|-------|------------------------------------------------------------|
| _initialized    | uint8                       | 0    | 0      | 1     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| _initializing   | bool                        | 0    | 1      | 1     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __gap           | uint256[50]                 | 1    | 0      | 1600  | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| _owner          | address                     | 51   | 0      | 20    | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __gap           | uint256[49]                 | 52   | 0      | 1568  | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| _pendingOwner   | address                     | 101  | 0      | 20    | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __gap           | uint256[49]                 | 102  | 0      | 1568  | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| addressManager  | address                     | 151  | 0      | 20    | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __gap           | uint256[49]                 | 152  | 0      | 1568  | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __reentry       | uint8                       | 201  | 0      | 1     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __paused        | uint8                       | 201  | 1      | 1     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| lastUnpausedAt  | uint64                      | 201  | 2      | 8     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __gap           | uint256[49]                 | 202  | 0      | 1568  | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| _blockhashes    | mapping(uint256 => bytes32) | 251  | 0      | 32    | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| publicInputHash | bytes32                     | 252  | 0      | 32    | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| parentGasExcess | uint64                      | 253  | 0      | 8     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| lastSyncedBlock | uint64                      | 253  | 8      | 8     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| parentTimestamp | uint64                      | 253  | 16     | 8     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| parentGasTarget | uint64                      | 253  | 24     | 8     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| l1ChainId       | uint64                      | 254  | 0      | 8     | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |
| __gap           | uint256[46]                 | 255  | 0      | 1472  | contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2 |

