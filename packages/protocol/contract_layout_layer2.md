## ERC1155Vault
| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                                  |
|--------------------|------------------------------------------------------|------|--------|-------|-----------------------------------------------------------|
| _initialized       | uint8                                                | 0    | 0      | 1     | ERC1155Vault |
| _initializing      | bool                                                 | 0    | 1      | 1     | ERC1155Vault |
| __gap              | uint256[50]                                          | 1    | 0      | 1600  | ERC1155Vault |
| _owner             | address                                              | 51   | 0      | 20    | ERC1155Vault |
| __gap              | uint256[49]                                          | 52   | 0      | 1568  | ERC1155Vault |
| _pendingOwner      | address                                              | 101  | 0      | 20    | ERC1155Vault |
| __gap              | uint256[49]                                          | 102  | 0      | 1568  | ERC1155Vault |
| addressManager     | address                                              | 151  | 0      | 20    | ERC1155Vault |
| __gap              | uint256[49]                                          | 152  | 0      | 1568  | ERC1155Vault |
| __reentry          | uint8                                                | 201  | 0      | 1     | ERC1155Vault |
| __paused           | uint8                                                | 201  | 1      | 1     | ERC1155Vault |
| __lastUnpausedAt   | uint64                                               | 201  | 2      | 8     | ERC1155Vault |
| __gap              | uint256[49]                                          | 202  | 0      | 1568  | ERC1155Vault |
| __gap              | uint256[50]                                          | 251  | 0      | 1600  | ERC1155Vault |
| bridgedToCanonical | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | ERC1155Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | ERC1155Vault |
| __gap              | uint256[48]                                          | 303  | 0      | 1536  | ERC1155Vault |
| __gap              | uint256[50]                                          | 351  | 0      | 1600  | ERC1155Vault |
| __gap              | uint256[50]                                          | 401  | 0      | 1600  | ERC1155Vault |
| __gap              | uint256[50]                                          | 451  | 0      | 1600  | ERC1155Vault |

## ERC20Vault
| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                              |
|--------------------|------------------------------------------------------|------|--------|-------|-------------------------------------------------------|
| _initialized       | uint8                                                | 0    | 0      | 1     | ERC20Vault |
| _initializing      | bool                                                 | 0    | 1      | 1     | ERC20Vault |
| __gap              | uint256[50]                                          | 1    | 0      | 1600  | ERC20Vault |
| _owner             | address                                              | 51   | 0      | 20    | ERC20Vault |
| __gap              | uint256[49]                                          | 52   | 0      | 1568  | ERC20Vault |
| _pendingOwner      | address                                              | 101  | 0      | 20    | ERC20Vault |
| __gap              | uint256[49]                                          | 102  | 0      | 1568  | ERC20Vault |
| addressManager     | address                                              | 151  | 0      | 20    | ERC20Vault |
| __gap              | uint256[49]                                          | 152  | 0      | 1568  | ERC20Vault |
| __reentry          | uint8                                                | 201  | 0      | 1     | ERC20Vault |
| __paused           | uint8                                                | 201  | 1      | 1     | ERC20Vault |
| __lastUnpausedAt   | uint64                                               | 201  | 2      | 8     | ERC20Vault |
| __gap              | uint256[49]                                          | 202  | 0      | 1568  | ERC20Vault |
| __gap              | uint256[50]                                          | 251  | 0      | 1600  | ERC20Vault |
| bridgedToCanonical | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | ERC20Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | ERC20Vault |
| btokenDenylist     | mapping(address => bool)                             | 303  | 0      | 32    | ERC20Vault |
| lastMigrationStart | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | ERC20Vault |
| __gap              | uint256[46]                                          | 305  | 0      | 1472  | ERC20Vault |

## ERC721Vault
| Name               | Type                                                 | Slot | Offset | Bytes | Contract                                                |
|--------------------|------------------------------------------------------|------|--------|-------|---------------------------------------------------------|
| _initialized       | uint8                                                | 0    | 0      | 1     | ERC721Vault |
| _initializing      | bool                                                 | 0    | 1      | 1     | ERC721Vault |
| __gap              | uint256[50]                                          | 1    | 0      | 1600  | ERC721Vault |
| _owner             | address                                              | 51   | 0      | 20    | ERC721Vault |
| __gap              | uint256[49]                                          | 52   | 0      | 1568  | ERC721Vault |
| _pendingOwner      | address                                              | 101  | 0      | 20    | ERC721Vault |
| __gap              | uint256[49]                                          | 102  | 0      | 1568  | ERC721Vault |
| addressManager     | address                                              | 151  | 0      | 20    | ERC721Vault |
| __gap              | uint256[49]                                          | 152  | 0      | 1568  | ERC721Vault |
| __reentry          | uint8                                                | 201  | 0      | 1     | ERC721Vault |
| __paused           | uint8                                                | 201  | 1      | 1     | ERC721Vault |
| __lastUnpausedAt   | uint64                                               | 201  | 2      | 8     | ERC721Vault |
| __gap              | uint256[49]                                          | 202  | 0      | 1568  | ERC721Vault |
| __gap              | uint256[50]                                          | 251  | 0      | 1600  | ERC721Vault |
| bridgedToCanonical | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | ERC721Vault |
| canonicalToBridged | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | ERC721Vault |
| __gap              | uint256[48]                                          | 303  | 0      | 1536  | ERC721Vault |
| __gap              | uint256[50]                                          | 351  | 0      | 1600  | ERC721Vault |

## BridgedERC20
| Name             | Type                                            | Slot | Offset | Bytes | Contract                                                  |
|------------------|-------------------------------------------------|------|--------|-------|-----------------------------------------------------------|
| _initialized     | uint8                                           | 0    | 0      | 1     | BridgedERC20 |
| _initializing    | bool                                            | 0    | 1      | 1     | BridgedERC20 |
| __gap            | uint256[50]                                     | 1    | 0      | 1600  | BridgedERC20 |
| _owner           | address                                         | 51   | 0      | 20    | BridgedERC20 |
| __gap            | uint256[49]                                     | 52   | 0      | 1568  | BridgedERC20 |
| _pendingOwner    | address                                         | 101  | 0      | 20    | BridgedERC20 |
| __gap            | uint256[49]                                     | 102  | 0      | 1568  | BridgedERC20 |
| addressManager   | address                                         | 151  | 0      | 20    | BridgedERC20 |
| __gap            | uint256[49]                                     | 152  | 0      | 1568  | BridgedERC20 |
| __reentry        | uint8                                           | 201  | 0      | 1     | BridgedERC20 |
| __paused         | uint8                                           | 201  | 1      | 1     | BridgedERC20 |
| __lastUnpausedAt | uint64                                          | 201  | 2      | 8     | BridgedERC20 |
| __gap            | uint256[49]                                     | 202  | 0      | 1568  | BridgedERC20 |
| _balances        | mapping(address => uint256)                     | 251  | 0      | 32    | BridgedERC20 |
| _allowances      | mapping(address => mapping(address => uint256)) | 252  | 0      | 32    | BridgedERC20 |
| _totalSupply     | uint256                                         | 253  | 0      | 32    | BridgedERC20 |
| _name            | string                                          | 254  | 0      | 32    | BridgedERC20 |
| _symbol          | string                                          | 255  | 0      | 32    | BridgedERC20 |
| __gap            | uint256[45]                                     | 256  | 0      | 1440  | BridgedERC20 |
| srcToken         | address                                         | 301  | 0      | 20    | BridgedERC20 |
| __srcDecimals    | uint8                                           | 301  | 20     | 1     | BridgedERC20 |
| srcChainId       | uint256                                         | 302  | 0      | 32    | BridgedERC20 |
| migratingAddress | address                                         | 303  | 0      | 20    | BridgedERC20 |
| migratingInbound | bool                                            | 303  | 20     | 1     | BridgedERC20 |
| __gap            | uint256[47]                                     | 304  | 0      | 1504  | BridgedERC20 |

## BridgedERC20V2
| Name             | Type                                                   | Slot | Offset | Bytes | Contract                                                      |
|------------------|--------------------------------------------------------|------|--------|-------|---------------------------------------------------------------|
| _initialized     | uint8                                                  | 0    | 0      | 1     | BridgedERC20V2 |
| _initializing    | bool                                                   | 0    | 1      | 1     | BridgedERC20V2 |
| __gap            | uint256[50]                                            | 1    | 0      | 1600  | BridgedERC20V2 |
| _owner           | address                                                | 51   | 0      | 20    | BridgedERC20V2 |
| __gap            | uint256[49]                                            | 52   | 0      | 1568  | BridgedERC20V2 |
| _pendingOwner    | address                                                | 101  | 0      | 20    | BridgedERC20V2 |
| __gap            | uint256[49]                                            | 102  | 0      | 1568  | BridgedERC20V2 |
| addressManager   | address                                                | 151  | 0      | 20    | BridgedERC20V2 |
| __gap            | uint256[49]                                            | 152  | 0      | 1568  | BridgedERC20V2 |
| __reentry        | uint8                                                  | 201  | 0      | 1     | BridgedERC20V2 |
| __paused         | uint8                                                  | 201  | 1      | 1     | BridgedERC20V2 |
| __lastUnpausedAt | uint64                                                 | 201  | 2      | 8     | BridgedERC20V2 |
| __gap            | uint256[49]                                            | 202  | 0      | 1568  | BridgedERC20V2 |
| _balances        | mapping(address => uint256)                            | 251  | 0      | 32    | BridgedERC20V2 |
| _allowances      | mapping(address => mapping(address => uint256))        | 252  | 0      | 32    | BridgedERC20V2 |
| _totalSupply     | uint256                                                | 253  | 0      | 32    | BridgedERC20V2 |
| _name            | string                                                 | 254  | 0      | 32    | BridgedERC20V2 |
| _symbol          | string                                                 | 255  | 0      | 32    | BridgedERC20V2 |
| __gap            | uint256[45]                                            | 256  | 0      | 1440  | BridgedERC20V2 |
| srcToken         | address                                                | 301  | 0      | 20    | BridgedERC20V2 |
| __srcDecimals    | uint8                                                  | 301  | 20     | 1     | BridgedERC20V2 |
| srcChainId       | uint256                                                | 302  | 0      | 32    | BridgedERC20V2 |
| migratingAddress | address                                                | 303  | 0      | 20    | BridgedERC20V2 |
| migratingInbound | bool                                                   | 303  | 20     | 1     | BridgedERC20V2 |
| __gap            | uint256[47]                                            | 304  | 0      | 1504  | BridgedERC20V2 |
| _hashedName      | bytes32                                                | 351  | 0      | 32    | BridgedERC20V2 |
| _hashedVersion   | bytes32                                                | 352  | 0      | 32    | BridgedERC20V2 |
| _name            | string                                                 | 353  | 0      | 32    | BridgedERC20V2 |
| _version         | string                                                 | 354  | 0      | 32    | BridgedERC20V2 |
| __gap            | uint256[48]                                            | 355  | 0      | 1536  | BridgedERC20V2 |
| _nonces          | mapping(address => struct CountersUpgradeable.Counter) | 403  | 0      | 32    | BridgedERC20V2 |
| __gap            | uint256[49]                                            | 404  | 0      | 1568  | BridgedERC20V2 |

## BridgedERC721
| Name               | Type                                         | Slot | Offset | Bytes | Contract                                                    |
|--------------------|----------------------------------------------|------|--------|-------|-------------------------------------------------------------|
| _initialized       | uint8                                        | 0    | 0      | 1     | BridgedERC721 |
| _initializing      | bool                                         | 0    | 1      | 1     | BridgedERC721 |
| __gap              | uint256[50]                                  | 1    | 0      | 1600  | BridgedERC721 |
| _owner             | address                                      | 51   | 0      | 20    | BridgedERC721 |
| __gap              | uint256[49]                                  | 52   | 0      | 1568  | BridgedERC721 |
| _pendingOwner      | address                                      | 101  | 0      | 20    | BridgedERC721 |
| __gap              | uint256[49]                                  | 102  | 0      | 1568  | BridgedERC721 |
| addressManager     | address                                      | 151  | 0      | 20    | BridgedERC721 |
| __gap              | uint256[49]                                  | 152  | 0      | 1568  | BridgedERC721 |
| __reentry          | uint8                                        | 201  | 0      | 1     | BridgedERC721 |
| __paused           | uint8                                        | 201  | 1      | 1     | BridgedERC721 |
| __lastUnpausedAt   | uint64                                       | 201  | 2      | 8     | BridgedERC721 |
| __gap              | uint256[49]                                  | 202  | 0      | 1568  | BridgedERC721 |
| __gap              | uint256[50]                                  | 251  | 0      | 1600  | BridgedERC721 |
| _name              | string                                       | 301  | 0      | 32    | BridgedERC721 |
| _symbol            | string                                       | 302  | 0      | 32    | BridgedERC721 |
| _owners            | mapping(uint256 => address)                  | 303  | 0      | 32    | BridgedERC721 |
| _balances          | mapping(address => uint256)                  | 304  | 0      | 32    | BridgedERC721 |
| _tokenApprovals    | mapping(uint256 => address)                  | 305  | 0      | 32    | BridgedERC721 |
| _operatorApprovals | mapping(address => mapping(address => bool)) | 306  | 0      | 32    | BridgedERC721 |
| __gap              | uint256[44]                                  | 307  | 0      | 1408  | BridgedERC721 |
| srcToken           | address                                      | 351  | 0      | 20    | BridgedERC721 |
| srcChainId         | uint256                                      | 352  | 0      | 32    | BridgedERC721 |
| __gap              | uint256[48]                                  | 353  | 0      | 1536  | BridgedERC721 |

## BridgedERC1155
| Name               | Type                                            | Slot | Offset | Bytes | Contract                                                      |
|--------------------|-------------------------------------------------|------|--------|-------|---------------------------------------------------------------|
| _initialized       | uint8                                           | 0    | 0      | 1     | BridgedERC1155 |
| _initializing      | bool                                            | 0    | 1      | 1     | BridgedERC1155 |
| __gap              | uint256[50]                                     | 1    | 0      | 1600  | BridgedERC1155 |
| _owner             | address                                         | 51   | 0      | 20    | BridgedERC1155 |
| __gap              | uint256[49]                                     | 52   | 0      | 1568  | BridgedERC1155 |
| _pendingOwner      | address                                         | 101  | 0      | 20    | BridgedERC1155 |
| __gap              | uint256[49]                                     | 102  | 0      | 1568  | BridgedERC1155 |
| addressManager     | address                                         | 151  | 0      | 20    | BridgedERC1155 |
| __gap              | uint256[49]                                     | 152  | 0      | 1568  | BridgedERC1155 |
| __reentry          | uint8                                           | 201  | 0      | 1     | BridgedERC1155 |
| __paused           | uint8                                           | 201  | 1      | 1     | BridgedERC1155 |
| __lastUnpausedAt   | uint64                                          | 201  | 2      | 8     | BridgedERC1155 |
| __gap              | uint256[49]                                     | 202  | 0      | 1568  | BridgedERC1155 |
| __gap              | uint256[50]                                     | 251  | 0      | 1600  | BridgedERC1155 |
| _balances          | mapping(uint256 => mapping(address => uint256)) | 301  | 0      | 32    | BridgedERC1155 |
| _operatorApprovals | mapping(address => mapping(address => bool))    | 302  | 0      | 32    | BridgedERC1155 |
| _uri               | string                                          | 303  | 0      | 32    | BridgedERC1155 |
| __gap              | uint256[47]                                     | 304  | 0      | 1504  | BridgedERC1155 |
| srcToken           | address                                         | 351  | 0      | 20    | BridgedERC1155 |
| srcChainId         | uint256                                         | 352  | 0      | 32    | BridgedERC1155 |
| symbol             | string                                          | 353  | 0      | 32    | BridgedERC1155 |
| name               | string                                          | 354  | 0      | 32    | BridgedERC1155 |
| __gap              | uint256[46]                                     | 355  | 0      | 1472  | BridgedERC1155 |

## Bridge
| Name             | Type                                    | Slot | Offset | Bytes | Contract                                  |
|------------------|-----------------------------------------|------|--------|-------|-------------------------------------------|
| _initialized     | uint8                                   | 0    | 0      | 1     | Bridge |
| _initializing    | bool                                    | 0    | 1      | 1     | Bridge |
| __gap            | uint256[50]                             | 1    | 0      | 1600  | Bridge |
| _owner           | address                                 | 51   | 0      | 20    | Bridge |
| __gap            | uint256[49]                             | 52   | 0      | 1568  | Bridge |
| _pendingOwner    | address                                 | 101  | 0      | 20    | Bridge |
| __gap            | uint256[49]                             | 102  | 0      | 1568  | Bridge |
| addressManager   | address                                 | 151  | 0      | 20    | Bridge |
| __gap            | uint256[49]                             | 152  | 0      | 1568  | Bridge |
| __reentry        | uint8                                   | 201  | 0      | 1     | Bridge |
| __paused         | uint8                                   | 201  | 1      | 1     | Bridge |
| __lastUnpausedAt | uint64                                  | 201  | 2      | 8     | Bridge |
| __gap            | uint256[49]                             | 202  | 0      | 1568  | Bridge |
| __reserved1      | uint64                                  | 251  | 0      | 8     | Bridge |
| nextMessageId    | uint64                                  | 251  | 8      | 8     | Bridge |
| messageStatus    | mapping(bytes32 => enum IBridge.Status) | 252  | 0      | 32    | Bridge |
| __ctx            | struct IBridge.Context                  | 253  | 0      | 64    | Bridge |
| __reserved2      | uint256                                 | 255  | 0      | 32    | Bridge |
| __reserved3      | uint256                                 | 256  | 0      | 32    | Bridge |
| __gap            | uint256[44]                             | 257  | 0      | 1408  | Bridge |

## QuotaManager
| Name             | Type                                          | Slot | Offset | Bytes | Contract                                              |
|------------------|-----------------------------------------------|------|--------|-------|-------------------------------------------------------|
| _initialized     | uint8                                         | 0    | 0      | 1     | QuotaManager |
| _initializing    | bool                                          | 0    | 1      | 1     | QuotaManager |
| __gap            | uint256[50]                                   | 1    | 0      | 1600  | QuotaManager |
| _owner           | address                                       | 51   | 0      | 20    | QuotaManager |
| __gap            | uint256[49]                                   | 52   | 0      | 1568  | QuotaManager |
| _pendingOwner    | address                                       | 101  | 0      | 20    | QuotaManager |
| __gap            | uint256[49]                                   | 102  | 0      | 1568  | QuotaManager |
| addressManager   | address                                       | 151  | 0      | 20    | QuotaManager |
| __gap            | uint256[49]                                   | 152  | 0      | 1568  | QuotaManager |
| __reentry        | uint8                                         | 201  | 0      | 1     | QuotaManager |
| __paused         | uint8                                         | 201  | 1      | 1     | QuotaManager |
| __lastUnpausedAt | uint64                                        | 201  | 2      | 8     | QuotaManager |
| __gap            | uint256[49]                                   | 202  | 0      | 1568  | QuotaManager |
| tokenQuota       | mapping(address => struct QuotaManager.Quota) | 251  | 0      | 32    | QuotaManager |
| quotaPeriod      | uint24                                        | 252  | 0      | 3     | QuotaManager |
| __gap            | uint256[48]                                   | 253  | 0      | 1536  | QuotaManager |

## AddressManager
| Name             | Type                                            | Slot | Offset | Bytes | Contract                                                  |
|------------------|-------------------------------------------------|------|--------|-------|-----------------------------------------------------------|
| _initialized     | uint8                                           | 0    | 0      | 1     | AddressManager |
| _initializing    | bool                                            | 0    | 1      | 1     | AddressManager |
| __gap            | uint256[50]                                     | 1    | 0      | 1600  | AddressManager |
| _owner           | address                                         | 51   | 0      | 20    | AddressManager |
| __gap            | uint256[49]                                     | 52   | 0      | 1568  | AddressManager |
| _pendingOwner    | address                                         | 101  | 0      | 20    | AddressManager |
| __gap            | uint256[49]                                     | 102  | 0      | 1568  | AddressManager |
| addressManager   | address                                         | 151  | 0      | 20    | AddressManager |
| __gap            | uint256[49]                                     | 152  | 0      | 1568  | AddressManager |
| __reentry        | uint8                                           | 201  | 0      | 1     | AddressManager |
| __paused         | uint8                                           | 201  | 1      | 1     | AddressManager |
| __lastUnpausedAt | uint64                                          | 201  | 2      | 8     | AddressManager |
| __gap            | uint256[49]                                     | 202  | 0      | 1568  | AddressManager |
| __addresses      | mapping(uint256 => mapping(bytes32 => address)) | 251  | 0      | 32    | AddressManager |
| __gap            | uint256[49]                                     | 252  | 0      | 1568  | AddressManager |

## AddressResolver
| Name           | Type        | Slot | Offset | Bytes | Contract                                                    |
|----------------|-------------|------|--------|-------|-------------------------------------------------------------|
| _initialized   | uint8       | 0    | 0      | 1     | AddressResolver |
| _initializing  | bool        | 0    | 1      | 1     | AddressResolver |
| addressManager | address     | 0    | 2      | 20    | AddressResolver |
| __gap          | uint256[49] | 1    | 0      | 1568  | AddressResolver |

## EssentialContract
| Name             | Type        | Slot | Offset | Bytes | Contract                                                        |
|------------------|-------------|------|--------|-------|-----------------------------------------------------------------|
| _initialized     | uint8       | 0    | 0      | 1     | EssentialContract |
| _initializing    | bool        | 0    | 1      | 1     | EssentialContract |
| __gap            | uint256[50] | 1    | 0      | 1600  | EssentialContract |
| _owner           | address     | 51   | 0      | 20    | EssentialContract |
| __gap            | uint256[49] | 52   | 0      | 1568  | EssentialContract |
| _pendingOwner    | address     | 101  | 0      | 20    | EssentialContract |
| __gap            | uint256[49] | 102  | 0      | 1568  | EssentialContract |
| addressManager   | address     | 151  | 0      | 20    | EssentialContract |
| __gap            | uint256[49] | 152  | 0      | 1568  | EssentialContract |
| __reentry        | uint8       | 201  | 0      | 1     | EssentialContract |
| __paused         | uint8       | 201  | 1      | 1     | EssentialContract |
| __lastUnpausedAt | uint64      | 201  | 2      | 8     | EssentialContract |
| __gap            | uint256[49] | 202  | 0      | 1568  | EssentialContract |

## SignalService
| Name             | Type                                          | Slot | Offset | Bytes | Contract                                                |
|------------------|-----------------------------------------------|------|--------|-------|---------------------------------------------------------|
| _initialized     | uint8                                         | 0    | 0      | 1     | SignalService |
| _initializing    | bool                                          | 0    | 1      | 1     | SignalService |
| __gap            | uint256[50]                                   | 1    | 0      | 1600  | SignalService |
| _owner           | address                                       | 51   | 0      | 20    | SignalService |
| __gap            | uint256[49]                                   | 52   | 0      | 1568  | SignalService |
| _pendingOwner    | address                                       | 101  | 0      | 20    | SignalService |
| __gap            | uint256[49]                                   | 102  | 0      | 1568  | SignalService |
| addressManager   | address                                       | 151  | 0      | 20    | SignalService |
| __gap            | uint256[49]                                   | 152  | 0      | 1568  | SignalService |
| __reentry        | uint8                                         | 201  | 0      | 1     | SignalService |
| __paused         | uint8                                         | 201  | 1      | 1     | SignalService |
| __lastUnpausedAt | uint64                                        | 201  | 2      | 8     | SignalService |
| __gap            | uint256[49]                                   | 202  | 0      | 1568  | SignalService |
| topBlockId       | mapping(uint64 => mapping(bytes32 => uint64)) | 251  | 0      | 32    | SignalService |
| isAuthorized     | mapping(address => bool)                      | 252  | 0      | 32    | SignalService |
| __gap            | uint256[48]                                   | 253  | 0      | 1536  | SignalService |

## BridgedTaikoToken
| Name                                                | Type                                                          | Slot | Offset | Bytes | Contract                                                       |
|-----------------------------------------------------|---------------------------------------------------------------|------|--------|-------|----------------------------------------------------------------|
| _initialized                                        | uint8                                                         | 0    | 0      | 1     | BridgedTaikoToken |
| _initializing                                       | bool                                                          | 0    | 1      | 1     | BridgedTaikoToken |
| __gap                                               | uint256[50]                                                   | 1    | 0      | 1600  | BridgedTaikoToken |
| _owner                                              | address                                                       | 51   | 0      | 20    | BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 52   | 0      | 1568  | BridgedTaikoToken |
| _pendingOwner                                       | address                                                       | 101  | 0      | 20    | BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 102  | 0      | 1568  | BridgedTaikoToken |
| addressManager                                      | address                                                       | 151  | 0      | 20    | BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 152  | 0      | 1568  | BridgedTaikoToken |
| __reentry                                           | uint8                                                         | 201  | 0      | 1     | BridgedTaikoToken |
| __paused                                            | uint8                                                         | 201  | 1      | 1     | BridgedTaikoToken |
| __lastUnpausedAt                                    | uint64                                                        | 201  | 2      | 8     | BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 202  | 0      | 1568  | BridgedTaikoToken |
| __slots_previously_used_by_ERC20SnapshotUpgradeable | uint256[50]                                                   | 251  | 0      | 1600  | BridgedTaikoToken |
| _balances                                           | mapping(address => uint256)                                   | 301  | 0      | 32    | BridgedTaikoToken |
| _allowances                                         | mapping(address => mapping(address => uint256))               | 302  | 0      | 32    | BridgedTaikoToken |
| _totalSupply                                        | uint256                                                       | 303  | 0      | 32    | BridgedTaikoToken |
| _name                                               | string                                                        | 304  | 0      | 32    | BridgedTaikoToken |
| _symbol                                             | string                                                        | 305  | 0      | 32    | BridgedTaikoToken |
| __gap                                               | uint256[45]                                                   | 306  | 0      | 1440  | BridgedTaikoToken |
| _hashedName                                         | bytes32                                                       | 351  | 0      | 32    | BridgedTaikoToken |
| _hashedVersion                                      | bytes32                                                       | 352  | 0      | 32    | BridgedTaikoToken |
| _name                                               | string                                                        | 353  | 0      | 32    | BridgedTaikoToken |
| _version                                            | string                                                        | 354  | 0      | 32    | BridgedTaikoToken |
| __gap                                               | uint256[48]                                                   | 355  | 0      | 1536  | BridgedTaikoToken |
| _nonces                                             | mapping(address => struct CountersUpgradeable.Counter)        | 403  | 0      | 32    | BridgedTaikoToken |
| _PERMIT_TYPEHASH_DEPRECATED_SLOT                    | bytes32                                                       | 404  | 0      | 32    | BridgedTaikoToken |
| __gap                                               | uint256[49]                                                   | 405  | 0      | 1568  | BridgedTaikoToken |
| _delegates                                          | mapping(address => address)                                   | 454  | 0      | 32    | BridgedTaikoToken |
| _checkpoints                                        | mapping(address => struct ERC20VotesUpgradeable.Checkpoint[]) | 455  | 0      | 32    | BridgedTaikoToken |
| _totalSupplyCheckpoints                             | struct ERC20VotesUpgradeable.Checkpoint[]                     | 456  | 0      | 32    | BridgedTaikoToken |
| __gap                                               | uint256[47]                                                   | 457  | 0      | 1504  | BridgedTaikoToken |
| __gap                                               | uint256[50]                                                   | 504  | 0      | 1600  | BridgedTaikoToken |

## DelegateOwner
| Name             | Type        | Slot | Offset | Bytes | Contract                                         |
|------------------|-------------|------|--------|-------|--------------------------------------------------|
| _initialized     | uint8       | 0    | 0      | 1     | DelegateOwner |
| _initializing    | bool        | 0    | 1      | 1     | DelegateOwner |
| __gap            | uint256[50] | 1    | 0      | 1600  | DelegateOwner |
| _owner           | address     | 51   | 0      | 20    | DelegateOwner |
| __gap            | uint256[49] | 52   | 0      | 1568  | DelegateOwner |
| _pendingOwner    | address     | 101  | 0      | 20    | DelegateOwner |
| __gap            | uint256[49] | 102  | 0      | 1568  | DelegateOwner |
| addressManager   | address     | 151  | 0      | 20    | DelegateOwner |
| __gap            | uint256[49] | 152  | 0      | 1568  | DelegateOwner |
| __reentry        | uint8       | 201  | 0      | 1     | DelegateOwner |
| __paused         | uint8       | 201  | 1      | 1     | DelegateOwner |
| __lastUnpausedAt | uint64      | 201  | 2      | 8     | DelegateOwner |
| __gap            | uint256[49] | 202  | 0      | 1568  | DelegateOwner |
| remoteChainId    | uint64      | 251  | 0      | 8     | DelegateOwner |
| admin            | address     | 251  | 8      | 20    | DelegateOwner |
| nextTxId         | uint64      | 252  | 0      | 8     | DelegateOwner |
| remoteOwner      | address     | 252  | 8      | 20    | DelegateOwner |
| __gap            | uint256[48] | 253  | 0      | 1536  | DelegateOwner |

## TaikoL2
| Name             | Type                        | Slot | Offset | Bytes | Contract                                   |
|------------------|-----------------------------|------|--------|-------|--------------------------------------------|
| _initialized     | uint8                       | 0    | 0      | 1     | TaikoL2 |
| _initializing    | bool                        | 0    | 1      | 1     | TaikoL2 |
| __gap            | uint256[50]                 | 1    | 0      | 1600  | TaikoL2 |
| _owner           | address                     | 51   | 0      | 20    | TaikoL2 |
| __gap            | uint256[49]                 | 52   | 0      | 1568  | TaikoL2 |
| _pendingOwner    | address                     | 101  | 0      | 20    | TaikoL2 |
| __gap            | uint256[49]                 | 102  | 0      | 1568  | TaikoL2 |
| addressManager   | address                     | 151  | 0      | 20    | TaikoL2 |
| __gap            | uint256[49]                 | 152  | 0      | 1568  | TaikoL2 |
| __reentry        | uint8                       | 201  | 0      | 1     | TaikoL2 |
| __paused         | uint8                       | 201  | 1      | 1     | TaikoL2 |
| __lastUnpausedAt | uint64                      | 201  | 2      | 8     | TaikoL2 |
| __gap            | uint256[49]                 | 202  | 0      | 1568  | TaikoL2 |
| _blockhashes     | mapping(uint256 => bytes32) | 251  | 0      | 32    | TaikoL2 |
| publicInputHash  | bytes32                     | 252  | 0      | 32    | TaikoL2 |
| parentGasExcess  | uint64                      | 253  | 0      | 8     | TaikoL2 |
| lastSyncedBlock  | uint64                      | 253  | 8      | 8     | TaikoL2 |
| parentTimestamp  | uint64                      | 253  | 16     | 8     | TaikoL2 |
| parentGasTarget  | uint64                      | 253  | 24     | 8     | TaikoL2 |
| l1ChainId        | uint64                      | 254  | 0      | 8     | TaikoL2 |
| __gap            | uint256[46]                 | 255  | 0      | 1472  | TaikoL2 |
| __gap            | uint256[50]                 | 301  | 0      | 1600  | TaikoL2 |

## HeklaTaikoL2
| Name             | Type                        | Slot | Offset | Bytes | Contract                                             |
|------------------|-----------------------------|------|--------|-------|------------------------------------------------------|
| _initialized     | uint8                       | 0    | 0      | 1     | HeklaTaikoL2 |
| _initializing    | bool                        | 0    | 1      | 1     | HeklaTaikoL2 |
| __gap            | uint256[50]                 | 1    | 0      | 1600  | HeklaTaikoL2 |
| _owner           | address                     | 51   | 0      | 20    | HeklaTaikoL2 |
| __gap            | uint256[49]                 | 52   | 0      | 1568  | HeklaTaikoL2 |
| _pendingOwner    | address                     | 101  | 0      | 20    | HeklaTaikoL2 |
| __gap            | uint256[49]                 | 102  | 0      | 1568  | HeklaTaikoL2 |
| addressManager   | address                     | 151  | 0      | 20    | HeklaTaikoL2 |
| __gap            | uint256[49]                 | 152  | 0      | 1568  | HeklaTaikoL2 |
| __reentry        | uint8                       | 201  | 0      | 1     | HeklaTaikoL2 |
| __paused         | uint8                       | 201  | 1      | 1     | HeklaTaikoL2 |
| __lastUnpausedAt | uint64                      | 201  | 2      | 8     | HeklaTaikoL2 |
| __gap            | uint256[49]                 | 202  | 0      | 1568  | HeklaTaikoL2 |
| _blockhashes     | mapping(uint256 => bytes32) | 251  | 0      | 32    | HeklaTaikoL2 |
| publicInputHash  | bytes32                     | 252  | 0      | 32    | HeklaTaikoL2 |
| parentGasExcess  | uint64                      | 253  | 0      | 8     | HeklaTaikoL2 |
| lastSyncedBlock  | uint64                      | 253  | 8      | 8     | HeklaTaikoL2 |
| parentTimestamp  | uint64                      | 253  | 16     | 8     | HeklaTaikoL2 |
| parentGasTarget  | uint64                      | 253  | 24     | 8     | HeklaTaikoL2 |
| l1ChainId        | uint64                      | 254  | 0      | 8     | HeklaTaikoL2 |
| __gap            | uint256[46]                 | 255  | 0      | 1472  | HeklaTaikoL2 |
| __gap            | uint256[50]                 | 301  | 0      | 1600  | HeklaTaikoL2 |

## MainnetTaikoL2
| Name             | Type                        | Slot | Offset | Bytes | Contract                                                   |
|------------------|-----------------------------|------|--------|-------|------------------------------------------------------------|
| _initialized     | uint8                       | 0    | 0      | 1     | MainnetTaikoL2 |
| _initializing    | bool                        | 0    | 1      | 1     | MainnetTaikoL2 |
| __gap            | uint256[50]                 | 1    | 0      | 1600  | MainnetTaikoL2 |
| _owner           | address                     | 51   | 0      | 20    | MainnetTaikoL2 |
| __gap            | uint256[49]                 | 52   | 0      | 1568  | MainnetTaikoL2 |
| _pendingOwner    | address                     | 101  | 0      | 20    | MainnetTaikoL2 |
| __gap            | uint256[49]                 | 102  | 0      | 1568  | MainnetTaikoL2 |
| addressManager   | address                     | 151  | 0      | 20    | MainnetTaikoL2 |
| __gap            | uint256[49]                 | 152  | 0      | 1568  | MainnetTaikoL2 |
| __reentry        | uint8                       | 201  | 0      | 1     | MainnetTaikoL2 |
| __paused         | uint8                       | 201  | 1      | 1     | MainnetTaikoL2 |
| __lastUnpausedAt | uint64                      | 201  | 2      | 8     | MainnetTaikoL2 |
| __gap            | uint256[49]                 | 202  | 0      | 1568  | MainnetTaikoL2 |
| _blockhashes     | mapping(uint256 => bytes32) | 251  | 0      | 32    | MainnetTaikoL2 |
| publicInputHash  | bytes32                     | 252  | 0      | 32    | MainnetTaikoL2 |
| parentGasExcess  | uint64                      | 253  | 0      | 8     | MainnetTaikoL2 |
| lastSyncedBlock  | uint64                      | 253  | 8      | 8     | MainnetTaikoL2 |
| parentTimestamp  | uint64                      | 253  | 16     | 8     | MainnetTaikoL2 |
| parentGasTarget  | uint64                      | 253  | 24     | 8     | MainnetTaikoL2 |
| l1ChainId        | uint64                      | 254  | 0      | 8     | MainnetTaikoL2 |
| __gap            | uint256[46]                 | 255  | 0      | 1472  | MainnetTaikoL2 |
| __gap            | uint256[50]                 | 301  | 0      | 1600  | MainnetTaikoL2 |

