## ERC1155Vault

| Name                        | Type                                                 | Slot | Offset | Bytes | Contract     |
| --------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ------------ |
| \_initialized               | uint8                                                | 0    | 0      | 1     | ERC1155Vault |
| \_initializing              | bool                                                 | 0    | 1      | 1     | ERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 1    | 0      | 1600  | ERC1155Vault |
| \_owner                     | address                                              | 51   | 0      | 20    | ERC1155Vault |
| \_\_gap                     | uint256[49]                                          | 52   | 0      | 1568  | ERC1155Vault |
| \_pendingOwner              | address                                              | 101  | 0      | 20    | ERC1155Vault |
| \_\_gap                     | uint256[49]                                          | 102  | 0      | 1568  | ERC1155Vault |
| resolver                    | contract IResolver                                   | 151  | 0      | 20    | ERC1155Vault |
| \_\_gap_old_AddressResolver | uint256[49]                                          | 152  | 0      | 1568  | ERC1155Vault |
| \_\_reentry                 | uint8                                                | 201  | 0      | 1     | ERC1155Vault |
| \_\_paused                  | uint8                                                | 201  | 1      | 1     | ERC1155Vault |
| \_\_lastUnpausedAt          | uint64                                               | 201  | 2      | 8     | ERC1155Vault |
| \_\_gap                     | uint256[49]                                          | 202  | 0      | 1568  | ERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 251  | 0      | 1600  | ERC1155Vault |
| bridgedToCanonical          | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | ERC1155Vault |
| canonicalToBridged          | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | ERC1155Vault |
| \_\_gap                     | uint256[48]                                          | 303  | 0      | 1536  | ERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 351  | 0      | 1600  | ERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 401  | 0      | 1600  | ERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 451  | 0      | 1600  | ERC1155Vault |

## ERC20Vault

| Name                        | Type                                                 | Slot | Offset | Bytes | Contract   |
| --------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ---------- |
| \_initialized               | uint8                                                | 0    | 0      | 1     | ERC20Vault |
| \_initializing              | bool                                                 | 0    | 1      | 1     | ERC20Vault |
| \_\_gap                     | uint256[50]                                          | 1    | 0      | 1600  | ERC20Vault |
| \_owner                     | address                                              | 51   | 0      | 20    | ERC20Vault |
| \_\_gap                     | uint256[49]                                          | 52   | 0      | 1568  | ERC20Vault |
| \_pendingOwner              | address                                              | 101  | 0      | 20    | ERC20Vault |
| \_\_gap                     | uint256[49]                                          | 102  | 0      | 1568  | ERC20Vault |
| resolver                    | contract IResolver                                   | 151  | 0      | 20    | ERC20Vault |
| \_\_gap_old_AddressResolver | uint256[49]                                          | 152  | 0      | 1568  | ERC20Vault |
| \_\_reentry                 | uint8                                                | 201  | 0      | 1     | ERC20Vault |
| \_\_paused                  | uint8                                                | 201  | 1      | 1     | ERC20Vault |
| \_\_lastUnpausedAt          | uint64                                               | 201  | 2      | 8     | ERC20Vault |
| \_\_gap                     | uint256[49]                                          | 202  | 0      | 1568  | ERC20Vault |
| \_\_gap                     | uint256[50]                                          | 251  | 0      | 1600  | ERC20Vault |
| bridgedToCanonical          | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | ERC20Vault |
| canonicalToBridged          | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | ERC20Vault |
| btokenDenylist              | mapping(address => bool)                             | 303  | 0      | 32    | ERC20Vault |
| lastMigrationStart          | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | ERC20Vault |
| \_\_gap                     | uint256[46]                                          | 305  | 0      | 1472  | ERC20Vault |

## ERC721Vault

| Name                        | Type                                                 | Slot | Offset | Bytes | Contract    |
| --------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ----------- |
| \_initialized               | uint8                                                | 0    | 0      | 1     | ERC721Vault |
| \_initializing              | bool                                                 | 0    | 1      | 1     | ERC721Vault |
| \_\_gap                     | uint256[50]                                          | 1    | 0      | 1600  | ERC721Vault |
| \_owner                     | address                                              | 51   | 0      | 20    | ERC721Vault |
| \_\_gap                     | uint256[49]                                          | 52   | 0      | 1568  | ERC721Vault |
| \_pendingOwner              | address                                              | 101  | 0      | 20    | ERC721Vault |
| \_\_gap                     | uint256[49]                                          | 102  | 0      | 1568  | ERC721Vault |
| resolver                    | contract IResolver                                   | 151  | 0      | 20    | ERC721Vault |
| \_\_gap_old_AddressResolver | uint256[49]                                          | 152  | 0      | 1568  | ERC721Vault |
| \_\_reentry                 | uint8                                                | 201  | 0      | 1     | ERC721Vault |
| \_\_paused                  | uint8                                                | 201  | 1      | 1     | ERC721Vault |
| \_\_lastUnpausedAt          | uint64                                               | 201  | 2      | 8     | ERC721Vault |
| \_\_gap                     | uint256[49]                                          | 202  | 0      | 1568  | ERC721Vault |
| \_\_gap                     | uint256[50]                                          | 251  | 0      | 1600  | ERC721Vault |
| bridgedToCanonical          | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | ERC721Vault |
| canonicalToBridged          | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | ERC721Vault |
| \_\_gap                     | uint256[48]                                          | 303  | 0      | 1536  | ERC721Vault |
| \_\_gap                     | uint256[50]                                          | 351  | 0      | 1600  | ERC721Vault |

## BridgedERC20

| Name                        | Type                                            | Slot | Offset | Bytes | Contract     |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ------------ |
| \_initialized               | uint8                                           | 0    | 0      | 1     | BridgedERC20 |
| \_initializing              | bool                                            | 0    | 1      | 1     | BridgedERC20 |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | BridgedERC20 |
| \_owner                     | address                                         | 51   | 0      | 20    | BridgedERC20 |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | BridgedERC20 |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | BridgedERC20 |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | BridgedERC20 |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | BridgedERC20 |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | BridgedERC20 |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | BridgedERC20 |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | BridgedERC20 |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | BridgedERC20 |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | BridgedERC20 |
| \_balances                  | mapping(address => uint256)                     | 251  | 0      | 32    | BridgedERC20 |
| \_allowances                | mapping(address => mapping(address => uint256)) | 252  | 0      | 32    | BridgedERC20 |
| \_totalSupply               | uint256                                         | 253  | 0      | 32    | BridgedERC20 |
| \_name                      | string                                          | 254  | 0      | 32    | BridgedERC20 |
| \_symbol                    | string                                          | 255  | 0      | 32    | BridgedERC20 |
| \_\_gap                     | uint256[45]                                     | 256  | 0      | 1440  | BridgedERC20 |
| srcToken                    | address                                         | 301  | 0      | 20    | BridgedERC20 |
| \_\_srcDecimals             | uint8                                           | 301  | 20     | 1     | BridgedERC20 |
| srcChainId                  | uint256                                         | 302  | 0      | 32    | BridgedERC20 |
| migratingAddress            | address                                         | 303  | 0      | 20    | BridgedERC20 |
| migratingInbound            | bool                                            | 303  | 20     | 1     | BridgedERC20 |
| \_\_gap                     | uint256[47]                                     | 304  | 0      | 1504  | BridgedERC20 |

## BridgedERC20V2

| Name                        | Type                                                   | Slot | Offset | Bytes | Contract       |
| --------------------------- | ------------------------------------------------------ | ---- | ------ | ----- | -------------- |
| \_initialized               | uint8                                                  | 0    | 0      | 1     | BridgedERC20V2 |
| \_initializing              | bool                                                   | 0    | 1      | 1     | BridgedERC20V2 |
| \_\_gap                     | uint256[50]                                            | 1    | 0      | 1600  | BridgedERC20V2 |
| \_owner                     | address                                                | 51   | 0      | 20    | BridgedERC20V2 |
| \_\_gap                     | uint256[49]                                            | 52   | 0      | 1568  | BridgedERC20V2 |
| \_pendingOwner              | address                                                | 101  | 0      | 20    | BridgedERC20V2 |
| \_\_gap                     | uint256[49]                                            | 102  | 0      | 1568  | BridgedERC20V2 |
| resolver                    | contract IResolver                                     | 151  | 0      | 20    | BridgedERC20V2 |
| \_\_gap_old_AddressResolver | uint256[49]                                            | 152  | 0      | 1568  | BridgedERC20V2 |
| \_\_reentry                 | uint8                                                  | 201  | 0      | 1     | BridgedERC20V2 |
| \_\_paused                  | uint8                                                  | 201  | 1      | 1     | BridgedERC20V2 |
| \_\_lastUnpausedAt          | uint64                                                 | 201  | 2      | 8     | BridgedERC20V2 |
| \_\_gap                     | uint256[49]                                            | 202  | 0      | 1568  | BridgedERC20V2 |
| \_balances                  | mapping(address => uint256)                            | 251  | 0      | 32    | BridgedERC20V2 |
| \_allowances                | mapping(address => mapping(address => uint256))        | 252  | 0      | 32    | BridgedERC20V2 |
| \_totalSupply               | uint256                                                | 253  | 0      | 32    | BridgedERC20V2 |
| \_name                      | string                                                 | 254  | 0      | 32    | BridgedERC20V2 |
| \_symbol                    | string                                                 | 255  | 0      | 32    | BridgedERC20V2 |
| \_\_gap                     | uint256[45]                                            | 256  | 0      | 1440  | BridgedERC20V2 |
| srcToken                    | address                                                | 301  | 0      | 20    | BridgedERC20V2 |
| \_\_srcDecimals             | uint8                                                  | 301  | 20     | 1     | BridgedERC20V2 |
| srcChainId                  | uint256                                                | 302  | 0      | 32    | BridgedERC20V2 |
| migratingAddress            | address                                                | 303  | 0      | 20    | BridgedERC20V2 |
| migratingInbound            | bool                                                   | 303  | 20     | 1     | BridgedERC20V2 |
| \_\_gap                     | uint256[47]                                            | 304  | 0      | 1504  | BridgedERC20V2 |
| \_hashedName                | bytes32                                                | 351  | 0      | 32    | BridgedERC20V2 |
| \_hashedVersion             | bytes32                                                | 352  | 0      | 32    | BridgedERC20V2 |
| \_name                      | string                                                 | 353  | 0      | 32    | BridgedERC20V2 |
| \_version                   | string                                                 | 354  | 0      | 32    | BridgedERC20V2 |
| \_\_gap                     | uint256[48]                                            | 355  | 0      | 1536  | BridgedERC20V2 |
| \_nonces                    | mapping(address => struct CountersUpgradeable.Counter) | 403  | 0      | 32    | BridgedERC20V2 |
| \_\_gap                     | uint256[49]                                            | 404  | 0      | 1568  | BridgedERC20V2 |

## BridgedERC721

| Name                        | Type                                         | Slot | Offset | Bytes | Contract      |
| --------------------------- | -------------------------------------------- | ---- | ------ | ----- | ------------- |
| \_initialized               | uint8                                        | 0    | 0      | 1     | BridgedERC721 |
| \_initializing              | bool                                         | 0    | 1      | 1     | BridgedERC721 |
| \_\_gap                     | uint256[50]                                  | 1    | 0      | 1600  | BridgedERC721 |
| \_owner                     | address                                      | 51   | 0      | 20    | BridgedERC721 |
| \_\_gap                     | uint256[49]                                  | 52   | 0      | 1568  | BridgedERC721 |
| \_pendingOwner              | address                                      | 101  | 0      | 20    | BridgedERC721 |
| \_\_gap                     | uint256[49]                                  | 102  | 0      | 1568  | BridgedERC721 |
| resolver                    | contract IResolver                           | 151  | 0      | 20    | BridgedERC721 |
| \_\_gap_old_AddressResolver | uint256[49]                                  | 152  | 0      | 1568  | BridgedERC721 |
| \_\_reentry                 | uint8                                        | 201  | 0      | 1     | BridgedERC721 |
| \_\_paused                  | uint8                                        | 201  | 1      | 1     | BridgedERC721 |
| \_\_lastUnpausedAt          | uint64                                       | 201  | 2      | 8     | BridgedERC721 |
| \_\_gap                     | uint256[49]                                  | 202  | 0      | 1568  | BridgedERC721 |
| \_\_gap                     | uint256[50]                                  | 251  | 0      | 1600  | BridgedERC721 |
| \_name                      | string                                       | 301  | 0      | 32    | BridgedERC721 |
| \_symbol                    | string                                       | 302  | 0      | 32    | BridgedERC721 |
| \_owners                    | mapping(uint256 => address)                  | 303  | 0      | 32    | BridgedERC721 |
| \_balances                  | mapping(address => uint256)                  | 304  | 0      | 32    | BridgedERC721 |
| \_tokenApprovals            | mapping(uint256 => address)                  | 305  | 0      | 32    | BridgedERC721 |
| \_operatorApprovals         | mapping(address => mapping(address => bool)) | 306  | 0      | 32    | BridgedERC721 |
| \_\_gap                     | uint256[44]                                  | 307  | 0      | 1408  | BridgedERC721 |
| srcToken                    | address                                      | 351  | 0      | 20    | BridgedERC721 |
| srcChainId                  | uint256                                      | 352  | 0      | 32    | BridgedERC721 |
| \_\_gap                     | uint256[48]                                  | 353  | 0      | 1536  | BridgedERC721 |

## BridgedERC1155

| Name                        | Type                                            | Slot | Offset | Bytes | Contract       |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | -------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | BridgedERC1155 |
| \_initializing              | bool                                            | 0    | 1      | 1     | BridgedERC1155 |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | BridgedERC1155 |
| \_owner                     | address                                         | 51   | 0      | 20    | BridgedERC1155 |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | BridgedERC1155 |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | BridgedERC1155 |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | BridgedERC1155 |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | BridgedERC1155 |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | BridgedERC1155 |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | BridgedERC1155 |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | BridgedERC1155 |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | BridgedERC1155 |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | BridgedERC1155 |
| \_\_gap                     | uint256[50]                                     | 251  | 0      | 1600  | BridgedERC1155 |
| \_balances                  | mapping(uint256 => mapping(address => uint256)) | 301  | 0      | 32    | BridgedERC1155 |
| \_operatorApprovals         | mapping(address => mapping(address => bool))    | 302  | 0      | 32    | BridgedERC1155 |
| \_uri                       | string                                          | 303  | 0      | 32    | BridgedERC1155 |
| \_\_gap                     | uint256[47]                                     | 304  | 0      | 1504  | BridgedERC1155 |
| srcToken                    | address                                         | 351  | 0      | 20    | BridgedERC1155 |
| srcChainId                  | uint256                                         | 352  | 0      | 32    | BridgedERC1155 |
| symbol                      | string                                          | 353  | 0      | 32    | BridgedERC1155 |
| name                        | string                                          | 354  | 0      | 32    | BridgedERC1155 |
| \_\_gap                     | uint256[46]                                     | 355  | 0      | 1472  | BridgedERC1155 |

## Bridge

| Name                        | Type                                    | Slot | Offset | Bytes | Contract |
| --------------------------- | --------------------------------------- | ---- | ------ | ----- | -------- |
| \_initialized               | uint8                                   | 0    | 0      | 1     | Bridge   |
| \_initializing              | bool                                    | 0    | 1      | 1     | Bridge   |
| \_\_gap                     | uint256[50]                             | 1    | 0      | 1600  | Bridge   |
| \_owner                     | address                                 | 51   | 0      | 20    | Bridge   |
| \_\_gap                     | uint256[49]                             | 52   | 0      | 1568  | Bridge   |
| \_pendingOwner              | address                                 | 101  | 0      | 20    | Bridge   |
| \_\_gap                     | uint256[49]                             | 102  | 0      | 1568  | Bridge   |
| resolver                    | contract IResolver                      | 151  | 0      | 20    | Bridge   |
| \_\_gap_old_AddressResolver | uint256[49]                             | 152  | 0      | 1568  | Bridge   |
| \_\_reentry                 | uint8                                   | 201  | 0      | 1     | Bridge   |
| \_\_paused                  | uint8                                   | 201  | 1      | 1     | Bridge   |
| \_\_lastUnpausedAt          | uint64                                  | 201  | 2      | 8     | Bridge   |
| \_\_gap                     | uint256[49]                             | 202  | 0      | 1568  | Bridge   |
| \_\_reserved1               | uint64                                  | 251  | 0      | 8     | Bridge   |
| nextMessageId               | uint64                                  | 251  | 8      | 8     | Bridge   |
| messageStatus               | mapping(bytes32 => enum IBridge.Status) | 252  | 0      | 32    | Bridge   |
| \_\_ctx                     | struct IBridge.Context                  | 253  | 0      | 64    | Bridge   |
| \_\_reserved2               | uint256                                 | 255  | 0      | 32    | Bridge   |
| \_\_reserved3               | uint256                                 | 256  | 0      | 32    | Bridge   |
| \_\_gap                     | uint256[44]                             | 257  | 0      | 1408  | Bridge   |

## QuotaManager

| Name                        | Type                                          | Slot | Offset | Bytes | Contract     |
| --------------------------- | --------------------------------------------- | ---- | ------ | ----- | ------------ |
| \_initialized               | uint8                                         | 0    | 0      | 1     | QuotaManager |
| \_initializing              | bool                                          | 0    | 1      | 1     | QuotaManager |
| \_\_gap                     | uint256[50]                                   | 1    | 0      | 1600  | QuotaManager |
| \_owner                     | address                                       | 51   | 0      | 20    | QuotaManager |
| \_\_gap                     | uint256[49]                                   | 52   | 0      | 1568  | QuotaManager |
| \_pendingOwner              | address                                       | 101  | 0      | 20    | QuotaManager |
| \_\_gap                     | uint256[49]                                   | 102  | 0      | 1568  | QuotaManager |
| resolver                    | contract IResolver                            | 151  | 0      | 20    | QuotaManager |
| \_\_gap_old_AddressResolver | uint256[49]                                   | 152  | 0      | 1568  | QuotaManager |
| \_\_reentry                 | uint8                                         | 201  | 0      | 1     | QuotaManager |
| \_\_paused                  | uint8                                         | 201  | 1      | 1     | QuotaManager |
| \_\_lastUnpausedAt          | uint64                                        | 201  | 2      | 8     | QuotaManager |
| \_\_gap                     | uint256[49]                                   | 202  | 0      | 1568  | QuotaManager |
| tokenQuota                  | mapping(address => struct QuotaManager.Quota) | 251  | 0      | 32    | QuotaManager |
| quotaPeriod                 | uint24                                        | 252  | 0      | 3     | QuotaManager |
| \_\_gap                     | uint256[48]                                   | 253  | 0      | 1536  | QuotaManager |

## DefaultResolver

| Name                        | Type                                            | Slot | Offset | Bytes | Contract        |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | --------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | DefaultResolver |
| \_initializing              | bool                                            | 0    | 1      | 1     | DefaultResolver |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | DefaultResolver |
| \_owner                     | address                                         | 51   | 0      | 20    | DefaultResolver |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | DefaultResolver |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | DefaultResolver |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | DefaultResolver |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | DefaultResolver |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | DefaultResolver |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | DefaultResolver |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | DefaultResolver |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | DefaultResolver |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | DefaultResolver |
| \_\_addresses               | mapping(uint256 => mapping(bytes32 => address)) | 251  | 0      | 32    | DefaultResolver |
| \_\_gap                     | uint256[49]                                     | 252  | 0      | 1568  | DefaultResolver |

## AddressResolver

| Name           | Type        | Slot | Offset | Bytes | Contract        |
| -------------- | ----------- | ---- | ------ | ----- | --------------- |
| \_initialized  | uint8       | 0    | 0      | 1     | AddressResolver |
| \_initializing | bool        | 0    | 1      | 1     | AddressResolver |
| addressManager | address     | 0    | 2      | 20    | AddressResolver |
| \_\_gap        | uint256[49] | 1    | 0      | 1568  | AddressResolver |

## EssentialContract

| Name                        | Type               | Slot | Offset | Bytes | Contract          |
| --------------------------- | ------------------ | ---- | ------ | ----- | ----------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | EssentialContract |
| \_initializing              | bool               | 0    | 1      | 1     | EssentialContract |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | EssentialContract |
| \_owner                     | address            | 51   | 0      | 20    | EssentialContract |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | EssentialContract |
| \_pendingOwner              | address            | 101  | 0      | 20    | EssentialContract |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | EssentialContract |
| resolver                    | contract IResolver | 151  | 0      | 20    | EssentialContract |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | EssentialContract |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | EssentialContract |
| \_\_paused                  | uint8              | 201  | 1      | 1     | EssentialContract |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | EssentialContract |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | EssentialContract |

## SignalService

| Name                        | Type                                          | Slot | Offset | Bytes | Contract      |
| --------------------------- | --------------------------------------------- | ---- | ------ | ----- | ------------- |
| \_initialized               | uint8                                         | 0    | 0      | 1     | SignalService |
| \_initializing              | bool                                          | 0    | 1      | 1     | SignalService |
| \_\_gap                     | uint256[50]                                   | 1    | 0      | 1600  | SignalService |
| \_owner                     | address                                       | 51   | 0      | 20    | SignalService |
| \_\_gap                     | uint256[49]                                   | 52   | 0      | 1568  | SignalService |
| \_pendingOwner              | address                                       | 101  | 0      | 20    | SignalService |
| \_\_gap                     | uint256[49]                                   | 102  | 0      | 1568  | SignalService |
| resolver                    | contract IResolver                            | 151  | 0      | 20    | SignalService |
| \_\_gap_old_AddressResolver | uint256[49]                                   | 152  | 0      | 1568  | SignalService |
| \_\_reentry                 | uint8                                         | 201  | 0      | 1     | SignalService |
| \_\_paused                  | uint8                                         | 201  | 1      | 1     | SignalService |
| \_\_lastUnpausedAt          | uint64                                        | 201  | 2      | 8     | SignalService |
| \_\_gap                     | uint256[49]                                   | 202  | 0      | 1568  | SignalService |
| topBlockId                  | mapping(uint64 => mapping(bytes32 => uint64)) | 251  | 0      | 32    | SignalService |
| isAuthorized                | mapping(address => bool)                      | 252  | 0      | 32    | SignalService |
| \_\_gap                     | uint256[48]                                   | 253  | 0      | 1536  | SignalService |

## TaikoToken

| Name                                                  | Type                                                          | Slot | Offset | Bytes | Contract   |
| ----------------------------------------------------- | ------------------------------------------------------------- | ---- | ------ | ----- | ---------- |
| \_initialized                                         | uint8                                                         | 0    | 0      | 1     | TaikoToken |
| \_initializing                                        | bool                                                          | 0    | 1      | 1     | TaikoToken |
| \_\_gap                                               | uint256[50]                                                   | 1    | 0      | 1600  | TaikoToken |
| \_owner                                               | address                                                       | 51   | 0      | 20    | TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 52   | 0      | 1568  | TaikoToken |
| \_pendingOwner                                        | address                                                       | 101  | 0      | 20    | TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 102  | 0      | 1568  | TaikoToken |
| resolver                                              | contract IResolver                                            | 151  | 0      | 20    | TaikoToken |
| \_\_gap_old_AddressResolver                           | uint256[49]                                                   | 152  | 0      | 1568  | TaikoToken |
| \_\_reentry                                           | uint8                                                         | 201  | 0      | 1     | TaikoToken |
| \_\_paused                                            | uint8                                                         | 201  | 1      | 1     | TaikoToken |
| \_\_lastUnpausedAt                                    | uint64                                                        | 201  | 2      | 8     | TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 202  | 0      | 1568  | TaikoToken |
| \_\_slots_previously_used_by_ERC20SnapshotUpgradeable | uint256[50]                                                   | 251  | 0      | 1600  | TaikoToken |
| \_balances                                            | mapping(address => uint256)                                   | 301  | 0      | 32    | TaikoToken |
| \_allowances                                          | mapping(address => mapping(address => uint256))               | 302  | 0      | 32    | TaikoToken |
| \_totalSupply                                         | uint256                                                       | 303  | 0      | 32    | TaikoToken |
| \_name                                                | string                                                        | 304  | 0      | 32    | TaikoToken |
| \_symbol                                              | string                                                        | 305  | 0      | 32    | TaikoToken |
| \_\_gap                                               | uint256[45]                                                   | 306  | 0      | 1440  | TaikoToken |
| \_hashedName                                          | bytes32                                                       | 351  | 0      | 32    | TaikoToken |
| \_hashedVersion                                       | bytes32                                                       | 352  | 0      | 32    | TaikoToken |
| \_name                                                | string                                                        | 353  | 0      | 32    | TaikoToken |
| \_version                                             | string                                                        | 354  | 0      | 32    | TaikoToken |
| \_\_gap                                               | uint256[48]                                                   | 355  | 0      | 1536  | TaikoToken |
| \_nonces                                              | mapping(address => struct CountersUpgradeable.Counter)        | 403  | 0      | 32    | TaikoToken |
| \_PERMIT_TYPEHASH_DEPRECATED_SLOT                     | bytes32                                                       | 404  | 0      | 32    | TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 405  | 0      | 1568  | TaikoToken |
| \_delegates                                           | mapping(address => address)                                   | 454  | 0      | 32    | TaikoToken |
| \_checkpoints                                         | mapping(address => struct ERC20VotesUpgradeable.Checkpoint[]) | 455  | 0      | 32    | TaikoToken |
| \_totalSupplyCheckpoints                              | struct ERC20VotesUpgradeable.Checkpoint[]                     | 456  | 0      | 32    | TaikoToken |
| \_\_gap                                               | uint256[47]                                                   | 457  | 0      | 1504  | TaikoToken |
| \_\_gap                                               | uint256[50]                                                   | 504  | 0      | 1600  | TaikoToken |

## ComposeVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract        |
| --------------------------- | ------------------ | ---- | ------ | ----- | --------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | ComposeVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | ComposeVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | ComposeVerifier |
| \_owner                     | address            | 51   | 0      | 20    | ComposeVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | ComposeVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | ComposeVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | ComposeVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | ComposeVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | ComposeVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | ComposeVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | ComposeVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | ComposeVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | ComposeVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | ComposeVerifier |

## TeeAnyVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract       |
| --------------------------- | ------------------ | ---- | ------ | ----- | -------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | TeeAnyVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | TeeAnyVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | TeeAnyVerifier |
| \_owner                     | address            | 51   | 0      | 20    | TeeAnyVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | TeeAnyVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | TeeAnyVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | TeeAnyVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | TeeAnyVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | TeeAnyVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | TeeAnyVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | TeeAnyVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | TeeAnyVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | TeeAnyVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | TeeAnyVerifier |
| \_\_gap                     | uint256[50]        | 301  | 0      | 1600  | TeeAnyVerifier |

## ZkAndTeeVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract         |
| --------------------------- | ------------------ | ---- | ------ | ----- | ---------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | ZkAndTeeVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | ZkAndTeeVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | ZkAndTeeVerifier |
| \_owner                     | address            | 51   | 0      | 20    | ZkAndTeeVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | ZkAndTeeVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | ZkAndTeeVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | ZkAndTeeVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | ZkAndTeeVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | ZkAndTeeVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | ZkAndTeeVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | ZkAndTeeVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | ZkAndTeeVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | ZkAndTeeVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | ZkAndTeeVerifier |
| \_\_gap                     | uint256[50]        | 301  | 0      | 1600  | ZkAndTeeVerifier |

## ZkAnyVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract      |
| --------------------------- | ------------------ | ---- | ------ | ----- | ------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | ZkAnyVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | ZkAnyVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | ZkAnyVerifier |
| \_owner                     | address            | 51   | 0      | 20    | ZkAnyVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | ZkAnyVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | ZkAnyVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | ZkAnyVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | ZkAnyVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | ZkAnyVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | ZkAnyVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | ZkAnyVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | ZkAnyVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | ZkAnyVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | ZkAnyVerifier |
| \_\_gap                     | uint256[50]        | 301  | 0      | 1600  | ZkAnyVerifier |

## Risc0Verifier

| Name                        | Type                     | Slot | Offset | Bytes | Contract      |
| --------------------------- | ------------------------ | ---- | ------ | ----- | ------------- |
| \_initialized               | uint8                    | 0    | 0      | 1     | Risc0Verifier |
| \_initializing              | bool                     | 0    | 1      | 1     | Risc0Verifier |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | Risc0Verifier |
| \_owner                     | address                  | 51   | 0      | 20    | Risc0Verifier |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | Risc0Verifier |
| \_pendingOwner              | address                  | 101  | 0      | 20    | Risc0Verifier |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | Risc0Verifier |
| resolver                    | contract IResolver       | 151  | 0      | 20    | Risc0Verifier |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | Risc0Verifier |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | Risc0Verifier |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | Risc0Verifier |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | Risc0Verifier |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | Risc0Verifier |
| isImageTrusted              | mapping(bytes32 => bool) | 251  | 0      | 32    | Risc0Verifier |
| \_\_gap                     | uint256[49]              | 252  | 0      | 1568  | Risc0Verifier |

## SP1Verifier

| Name                        | Type                     | Slot | Offset | Bytes | Contract    |
| --------------------------- | ------------------------ | ---- | ------ | ----- | ----------- |
| \_initialized               | uint8                    | 0    | 0      | 1     | SP1Verifier |
| \_initializing              | bool                     | 0    | 1      | 1     | SP1Verifier |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | SP1Verifier |
| \_owner                     | address                  | 51   | 0      | 20    | SP1Verifier |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | SP1Verifier |
| \_pendingOwner              | address                  | 101  | 0      | 20    | SP1Verifier |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | SP1Verifier |
| resolver                    | contract IResolver       | 151  | 0      | 20    | SP1Verifier |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | SP1Verifier |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | SP1Verifier |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | SP1Verifier |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | SP1Verifier |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | SP1Verifier |
| isProgramTrusted            | mapping(bytes32 => bool) | 251  | 0      | 32    | SP1Verifier |
| \_\_gap                     | uint256[49]              | 252  | 0      | 1568  | SP1Verifier |

## SgxVerifier

| Name                        | Type                                            | Slot | Offset | Bytes | Contract    |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ----------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | SgxVerifier |
| \_initializing              | bool                                            | 0    | 1      | 1     | SgxVerifier |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | SgxVerifier |
| \_owner                     | address                                         | 51   | 0      | 20    | SgxVerifier |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | SgxVerifier |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | SgxVerifier |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | SgxVerifier |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | SgxVerifier |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | SgxVerifier |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | SgxVerifier |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | SgxVerifier |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | SgxVerifier |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | SgxVerifier |
| nextInstanceId              | uint256                                         | 251  | 0      | 32    | SgxVerifier |
| instances                   | mapping(uint256 => struct SgxVerifier.Instance) | 252  | 0      | 32    | SgxVerifier |
| addressRegistered           | mapping(address => bool)                        | 253  | 0      | 32    | SgxVerifier |
| \_\_gap                     | uint256[47]                                     | 254  | 0      | 1504  | SgxVerifier |

## AutomataDcapV3Attestation

| Name                        | Type                                            | Slot | Offset | Bytes | Contract                  |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ------------------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | AutomataDcapV3Attestation |
| \_initializing              | bool                                            | 0    | 1      | 1     | AutomataDcapV3Attestation |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | AutomataDcapV3Attestation |
| \_owner                     | address                                         | 51   | 0      | 20    | AutomataDcapV3Attestation |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | AutomataDcapV3Attestation |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | AutomataDcapV3Attestation |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | AutomataDcapV3Attestation |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | AutomataDcapV3Attestation |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | AutomataDcapV3Attestation |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | AutomataDcapV3Attestation |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | AutomataDcapV3Attestation |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | AutomataDcapV3Attestation |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | AutomataDcapV3Attestation |
| sigVerifyLib                | contract ISigVerifyLib                          | 251  | 0      | 20    | AutomataDcapV3Attestation |
| pemCertLib                  | contract IPEMCertChainLib                       | 252  | 0      | 20    | AutomataDcapV3Attestation |
| checkLocalEnclaveReport     | bool                                            | 252  | 20     | 1     | AutomataDcapV3Attestation |
| trustedUserMrEnclave        | mapping(bytes32 => bool)                        | 253  | 0      | 32    | AutomataDcapV3Attestation |
| trustedUserMrSigner         | mapping(bytes32 => bool)                        | 254  | 0      | 32    | AutomataDcapV3Attestation |
| serialNumIsRevoked          | mapping(uint256 => mapping(bytes => bool))      | 255  | 0      | 32    | AutomataDcapV3Attestation |
| tcbInfo                     | mapping(string => struct TCBInfoStruct.TCBInfo) | 256  | 0      | 32    | AutomataDcapV3Attestation |
| qeIdentity                  | struct EnclaveIdStruct.EnclaveId                | 257  | 0      | 128   | AutomataDcapV3Attestation |
| \_\_gap                     | uint256[39]                                     | 261  | 0      | 1248  | AutomataDcapV3Attestation |

## TaikoL1

| Name                        | Type                   | Slot | Offset | Bytes | Contract |
| --------------------------- | ---------------------- | ---- | ------ | ----- | -------- |
| \_initialized               | uint8                  | 0    | 0      | 1     | TaikoL1  |
| \_initializing              | bool                   | 0    | 1      | 1     | TaikoL1  |
| \_\_gap                     | uint256[50]            | 1    | 0      | 1600  | TaikoL1  |
| \_owner                     | address                | 51   | 0      | 20    | TaikoL1  |
| \_\_gap                     | uint256[49]            | 52   | 0      | 1568  | TaikoL1  |
| \_pendingOwner              | address                | 101  | 0      | 20    | TaikoL1  |
| \_\_gap                     | uint256[49]            | 102  | 0      | 1568  | TaikoL1  |
| resolver                    | contract IResolver     | 151  | 0      | 20    | TaikoL1  |
| \_\_gap_old_AddressResolver | uint256[49]            | 152  | 0      | 1568  | TaikoL1  |
| \_\_reentry                 | uint8                  | 201  | 0      | 1     | TaikoL1  |
| \_\_paused                  | uint8                  | 201  | 1      | 1     | TaikoL1  |
| \_\_lastUnpausedAt          | uint64                 | 201  | 2      | 8     | TaikoL1  |
| \_\_gap                     | uint256[49]            | 202  | 0      | 1568  | TaikoL1  |
| state                       | struct TaikoData.State | 251  | 0      | 1600  | TaikoL1  |
| \_\_gap                     | uint256[50]            | 301  | 0      | 1600  | TaikoL1  |

## HeklaTaikoL1

| Name                        | Type                   | Slot | Offset | Bytes | Contract     |
| --------------------------- | ---------------------- | ---- | ------ | ----- | ------------ |
| \_initialized               | uint8                  | 0    | 0      | 1     | HeklaTaikoL1 |
| \_initializing              | bool                   | 0    | 1      | 1     | HeklaTaikoL1 |
| \_\_gap                     | uint256[50]            | 1    | 0      | 1600  | HeklaTaikoL1 |
| \_owner                     | address                | 51   | 0      | 20    | HeklaTaikoL1 |
| \_\_gap                     | uint256[49]            | 52   | 0      | 1568  | HeklaTaikoL1 |
| \_pendingOwner              | address                | 101  | 0      | 20    | HeklaTaikoL1 |
| \_\_gap                     | uint256[49]            | 102  | 0      | 1568  | HeklaTaikoL1 |
| resolver                    | contract IResolver     | 151  | 0      | 20    | HeklaTaikoL1 |
| \_\_gap_old_AddressResolver | uint256[49]            | 152  | 0      | 1568  | HeklaTaikoL1 |
| \_\_reentry                 | uint8                  | 201  | 0      | 1     | HeklaTaikoL1 |
| \_\_paused                  | uint8                  | 201  | 1      | 1     | HeklaTaikoL1 |
| \_\_lastUnpausedAt          | uint64                 | 201  | 2      | 8     | HeklaTaikoL1 |
| \_\_gap                     | uint256[49]            | 202  | 0      | 1568  | HeklaTaikoL1 |
| state                       | struct TaikoData.State | 251  | 0      | 1600  | HeklaTaikoL1 |
| \_\_gap                     | uint256[50]            | 301  | 0      | 1600  | HeklaTaikoL1 |

## HeklaTierRouter

| Name | Type | Slot | Offset | Bytes | Contract |
| ---- | ---- | ---- | ------ | ----- | -------- |

## MainnetBridge

| Name                        | Type                                    | Slot | Offset | Bytes | Contract      |
| --------------------------- | --------------------------------------- | ---- | ------ | ----- | ------------- |
| \_initialized               | uint8                                   | 0    | 0      | 1     | MainnetBridge |
| \_initializing              | bool                                    | 0    | 1      | 1     | MainnetBridge |
| \_\_gap                     | uint256[50]                             | 1    | 0      | 1600  | MainnetBridge |
| \_owner                     | address                                 | 51   | 0      | 20    | MainnetBridge |
| \_\_gap                     | uint256[49]                             | 52   | 0      | 1568  | MainnetBridge |
| \_pendingOwner              | address                                 | 101  | 0      | 20    | MainnetBridge |
| \_\_gap                     | uint256[49]                             | 102  | 0      | 1568  | MainnetBridge |
| resolver                    | contract IResolver                      | 151  | 0      | 20    | MainnetBridge |
| \_\_gap_old_AddressResolver | uint256[49]                             | 152  | 0      | 1568  | MainnetBridge |
| \_\_reentry                 | uint8                                   | 201  | 0      | 1     | MainnetBridge |
| \_\_paused                  | uint8                                   | 201  | 1      | 1     | MainnetBridge |
| \_\_lastUnpausedAt          | uint64                                  | 201  | 2      | 8     | MainnetBridge |
| \_\_gap                     | uint256[49]                             | 202  | 0      | 1568  | MainnetBridge |
| \_\_reserved1               | uint64                                  | 251  | 0      | 8     | MainnetBridge |
| nextMessageId               | uint64                                  | 251  | 8      | 8     | MainnetBridge |
| messageStatus               | mapping(bytes32 => enum IBridge.Status) | 252  | 0      | 32    | MainnetBridge |
| \_\_ctx                     | struct IBridge.Context                  | 253  | 0      | 64    | MainnetBridge |
| \_\_reserved2               | uint256                                 | 255  | 0      | 32    | MainnetBridge |
| \_\_reserved3               | uint256                                 | 256  | 0      | 32    | MainnetBridge |
| \_\_gap                     | uint256[44]                             | 257  | 0      | 1408  | MainnetBridge |

## MainnetSignalService

| Name                        | Type                                          | Slot | Offset | Bytes | Contract             |
| --------------------------- | --------------------------------------------- | ---- | ------ | ----- | -------------------- |
| \_initialized               | uint8                                         | 0    | 0      | 1     | MainnetSignalService |
| \_initializing              | bool                                          | 0    | 1      | 1     | MainnetSignalService |
| \_\_gap                     | uint256[50]                                   | 1    | 0      | 1600  | MainnetSignalService |
| \_owner                     | address                                       | 51   | 0      | 20    | MainnetSignalService |
| \_\_gap                     | uint256[49]                                   | 52   | 0      | 1568  | MainnetSignalService |
| \_pendingOwner              | address                                       | 101  | 0      | 20    | MainnetSignalService |
| \_\_gap                     | uint256[49]                                   | 102  | 0      | 1568  | MainnetSignalService |
| resolver                    | contract IResolver                            | 151  | 0      | 20    | MainnetSignalService |
| \_\_gap_old_AddressResolver | uint256[49]                                   | 152  | 0      | 1568  | MainnetSignalService |
| \_\_reentry                 | uint8                                         | 201  | 0      | 1     | MainnetSignalService |
| \_\_paused                  | uint8                                         | 201  | 1      | 1     | MainnetSignalService |
| \_\_lastUnpausedAt          | uint64                                        | 201  | 2      | 8     | MainnetSignalService |
| \_\_gap                     | uint256[49]                                   | 202  | 0      | 1568  | MainnetSignalService |
| topBlockId                  | mapping(uint64 => mapping(bytes32 => uint64)) | 251  | 0      | 32    | MainnetSignalService |
| isAuthorized                | mapping(address => bool)                      | 252  | 0      | 32    | MainnetSignalService |
| \_\_gap                     | uint256[48]                                   | 253  | 0      | 1536  | MainnetSignalService |

## MainnetERC20Vault

| Name                        | Type                                                 | Slot | Offset | Bytes | Contract          |
| --------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ----------------- |
| \_initialized               | uint8                                                | 0    | 0      | 1     | MainnetERC20Vault |
| \_initializing              | bool                                                 | 0    | 1      | 1     | MainnetERC20Vault |
| \_\_gap                     | uint256[50]                                          | 1    | 0      | 1600  | MainnetERC20Vault |
| \_owner                     | address                                              | 51   | 0      | 20    | MainnetERC20Vault |
| \_\_gap                     | uint256[49]                                          | 52   | 0      | 1568  | MainnetERC20Vault |
| \_pendingOwner              | address                                              | 101  | 0      | 20    | MainnetERC20Vault |
| \_\_gap                     | uint256[49]                                          | 102  | 0      | 1568  | MainnetERC20Vault |
| resolver                    | contract IResolver                                   | 151  | 0      | 20    | MainnetERC20Vault |
| \_\_gap_old_AddressResolver | uint256[49]                                          | 152  | 0      | 1568  | MainnetERC20Vault |
| \_\_reentry                 | uint8                                                | 201  | 0      | 1     | MainnetERC20Vault |
| \_\_paused                  | uint8                                                | 201  | 1      | 1     | MainnetERC20Vault |
| \_\_lastUnpausedAt          | uint64                                               | 201  | 2      | 8     | MainnetERC20Vault |
| \_\_gap                     | uint256[49]                                          | 202  | 0      | 1568  | MainnetERC20Vault |
| \_\_gap                     | uint256[50]                                          | 251  | 0      | 1600  | MainnetERC20Vault |
| bridgedToCanonical          | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | MainnetERC20Vault |
| canonicalToBridged          | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | MainnetERC20Vault |
| btokenDenylist              | mapping(address => bool)                             | 303  | 0      | 32    | MainnetERC20Vault |
| lastMigrationStart          | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | MainnetERC20Vault |
| \_\_gap                     | uint256[46]                                          | 305  | 0      | 1472  | MainnetERC20Vault |

## MainnetERC1155Vault

| Name                        | Type                                                 | Slot | Offset | Bytes | Contract            |
| --------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ------------------- |
| \_initialized               | uint8                                                | 0    | 0      | 1     | MainnetERC1155Vault |
| \_initializing              | bool                                                 | 0    | 1      | 1     | MainnetERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 1    | 0      | 1600  | MainnetERC1155Vault |
| \_owner                     | address                                              | 51   | 0      | 20    | MainnetERC1155Vault |
| \_\_gap                     | uint256[49]                                          | 52   | 0      | 1568  | MainnetERC1155Vault |
| \_pendingOwner              | address                                              | 101  | 0      | 20    | MainnetERC1155Vault |
| \_\_gap                     | uint256[49]                                          | 102  | 0      | 1568  | MainnetERC1155Vault |
| resolver                    | contract IResolver                                   | 151  | 0      | 20    | MainnetERC1155Vault |
| \_\_gap_old_AddressResolver | uint256[49]                                          | 152  | 0      | 1568  | MainnetERC1155Vault |
| \_\_reentry                 | uint8                                                | 201  | 0      | 1     | MainnetERC1155Vault |
| \_\_paused                  | uint8                                                | 201  | 1      | 1     | MainnetERC1155Vault |
| \_\_lastUnpausedAt          | uint64                                               | 201  | 2      | 8     | MainnetERC1155Vault |
| \_\_gap                     | uint256[49]                                          | 202  | 0      | 1568  | MainnetERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 251  | 0      | 1600  | MainnetERC1155Vault |
| bridgedToCanonical          | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | MainnetERC1155Vault |
| canonicalToBridged          | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | MainnetERC1155Vault |
| \_\_gap                     | uint256[48]                                          | 303  | 0      | 1536  | MainnetERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 351  | 0      | 1600  | MainnetERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 401  | 0      | 1600  | MainnetERC1155Vault |
| \_\_gap                     | uint256[50]                                          | 451  | 0      | 1600  | MainnetERC1155Vault |

## MainnetERC721Vault

| Name                        | Type                                                 | Slot | Offset | Bytes | Contract           |
| --------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ------------------ |
| \_initialized               | uint8                                                | 0    | 0      | 1     | MainnetERC721Vault |
| \_initializing              | bool                                                 | 0    | 1      | 1     | MainnetERC721Vault |
| \_\_gap                     | uint256[50]                                          | 1    | 0      | 1600  | MainnetERC721Vault |
| \_owner                     | address                                              | 51   | 0      | 20    | MainnetERC721Vault |
| \_\_gap                     | uint256[49]                                          | 52   | 0      | 1568  | MainnetERC721Vault |
| \_pendingOwner              | address                                              | 101  | 0      | 20    | MainnetERC721Vault |
| \_\_gap                     | uint256[49]                                          | 102  | 0      | 1568  | MainnetERC721Vault |
| resolver                    | contract IResolver                                   | 151  | 0      | 20    | MainnetERC721Vault |
| \_\_gap_old_AddressResolver | uint256[49]                                          | 152  | 0      | 1568  | MainnetERC721Vault |
| \_\_reentry                 | uint8                                                | 201  | 0      | 1     | MainnetERC721Vault |
| \_\_paused                  | uint8                                                | 201  | 1      | 1     | MainnetERC721Vault |
| \_\_lastUnpausedAt          | uint64                                               | 201  | 2      | 8     | MainnetERC721Vault |
| \_\_gap                     | uint256[49]                                          | 202  | 0      | 1568  | MainnetERC721Vault |
| \_\_gap                     | uint256[50]                                          | 251  | 0      | 1600  | MainnetERC721Vault |
| bridgedToCanonical          | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | MainnetERC721Vault |
| canonicalToBridged          | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | MainnetERC721Vault |
| \_\_gap                     | uint256[48]                                          | 303  | 0      | 1536  | MainnetERC721Vault |
| \_\_gap                     | uint256[50]                                          | 351  | 0      | 1600  | MainnetERC721Vault |

## MainnetSharedDefaultResolver

| Name                        | Type                                            | Slot | Offset | Bytes | Contract                     |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ---------------------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | MainnetSharedDefaultResolver |
| \_initializing              | bool                                            | 0    | 1      | 1     | MainnetSharedDefaultResolver |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | MainnetSharedDefaultResolver |
| \_owner                     | address                                         | 51   | 0      | 20    | MainnetSharedDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | MainnetSharedDefaultResolver |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | MainnetSharedDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | MainnetSharedDefaultResolver |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | MainnetSharedDefaultResolver |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | MainnetSharedDefaultResolver |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | MainnetSharedDefaultResolver |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | MainnetSharedDefaultResolver |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | MainnetSharedDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | MainnetSharedDefaultResolver |
| \_\_addresses               | mapping(uint256 => mapping(bytes32 => address)) | 251  | 0      | 32    | MainnetSharedDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 252  | 0      | 1568  | MainnetSharedDefaultResolver |

## RollupAddressCache

| Name | Type | Slot | Offset | Bytes | Contract |
| ---- | ---- | ---- | ------ | ----- | -------- |

## SharedAddressCache

| Name | Type | Slot | Offset | Bytes | Contract |
| ---- | ---- | ---- | ------ | ----- | -------- |

## AddressCache

| Name | Type | Slot | Offset | Bytes | Contract |
| ---- | ---- | ---- | ------ | ----- | -------- |

## MainnetSgxVerifier

| Name                        | Type                                            | Slot | Offset | Bytes | Contract           |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ------------------ |
| \_initialized               | uint8                                           | 0    | 0      | 1     | MainnetSgxVerifier |
| \_initializing              | bool                                            | 0    | 1      | 1     | MainnetSgxVerifier |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | MainnetSgxVerifier |
| \_owner                     | address                                         | 51   | 0      | 20    | MainnetSgxVerifier |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | MainnetSgxVerifier |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | MainnetSgxVerifier |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | MainnetSgxVerifier |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | MainnetSgxVerifier |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | MainnetSgxVerifier |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | MainnetSgxVerifier |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | MainnetSgxVerifier |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | MainnetSgxVerifier |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | MainnetSgxVerifier |
| nextInstanceId              | uint256                                         | 251  | 0      | 32    | MainnetSgxVerifier |
| instances                   | mapping(uint256 => struct SgxVerifier.Instance) | 252  | 0      | 32    | MainnetSgxVerifier |
| addressRegistered           | mapping(address => bool)                        | 253  | 0      | 32    | MainnetSgxVerifier |
| \_\_gap                     | uint256[47]                                     | 254  | 0      | 1504  | MainnetSgxVerifier |

## MainnetSP1Verifier

| Name                        | Type                     | Slot | Offset | Bytes | Contract           |
| --------------------------- | ------------------------ | ---- | ------ | ----- | ------------------ |
| \_initialized               | uint8                    | 0    | 0      | 1     | MainnetSP1Verifier |
| \_initializing              | bool                     | 0    | 1      | 1     | MainnetSP1Verifier |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | MainnetSP1Verifier |
| \_owner                     | address                  | 51   | 0      | 20    | MainnetSP1Verifier |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | MainnetSP1Verifier |
| \_pendingOwner              | address                  | 101  | 0      | 20    | MainnetSP1Verifier |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | MainnetSP1Verifier |
| resolver                    | contract IResolver       | 151  | 0      | 20    | MainnetSP1Verifier |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | MainnetSP1Verifier |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | MainnetSP1Verifier |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | MainnetSP1Verifier |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | MainnetSP1Verifier |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | MainnetSP1Verifier |
| isProgramTrusted            | mapping(bytes32 => bool) | 251  | 0      | 32    | MainnetSP1Verifier |
| \_\_gap                     | uint256[49]              | 252  | 0      | 1568  | MainnetSP1Verifier |

## MainnetZkAnyVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract             |
| --------------------------- | ------------------ | ---- | ------ | ----- | -------------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | MainnetZkAnyVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | MainnetZkAnyVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | MainnetZkAnyVerifier |
| \_owner                     | address            | 51   | 0      | 20    | MainnetZkAnyVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | MainnetZkAnyVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | MainnetZkAnyVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | MainnetZkAnyVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | MainnetZkAnyVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | MainnetZkAnyVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | MainnetZkAnyVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | MainnetZkAnyVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | MainnetZkAnyVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | MainnetZkAnyVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | MainnetZkAnyVerifier |
| \_\_gap                     | uint256[50]        | 301  | 0      | 1600  | MainnetZkAnyVerifier |

## MainnetRisc0Verifier

| Name                        | Type                     | Slot | Offset | Bytes | Contract             |
| --------------------------- | ------------------------ | ---- | ------ | ----- | -------------------- |
| \_initialized               | uint8                    | 0    | 0      | 1     | MainnetRisc0Verifier |
| \_initializing              | bool                     | 0    | 1      | 1     | MainnetRisc0Verifier |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | MainnetRisc0Verifier |
| \_owner                     | address                  | 51   | 0      | 20    | MainnetRisc0Verifier |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | MainnetRisc0Verifier |
| \_pendingOwner              | address                  | 101  | 0      | 20    | MainnetRisc0Verifier |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | MainnetRisc0Verifier |
| resolver                    | contract IResolver       | 151  | 0      | 20    | MainnetRisc0Verifier |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | MainnetRisc0Verifier |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | MainnetRisc0Verifier |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | MainnetRisc0Verifier |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | MainnetRisc0Verifier |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | MainnetRisc0Verifier |
| isImageTrusted              | mapping(bytes32 => bool) | 251  | 0      | 32    | MainnetRisc0Verifier |
| \_\_gap                     | uint256[49]              | 252  | 0      | 1568  | MainnetRisc0Verifier |

## MainnetZkAndTeeVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract                |
| --------------------------- | ------------------ | ---- | ------ | ----- | ----------------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | MainnetZkAndTeeVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | MainnetZkAndTeeVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | MainnetZkAndTeeVerifier |
| \_owner                     | address            | 51   | 0      | 20    | MainnetZkAndTeeVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | MainnetZkAndTeeVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | MainnetZkAndTeeVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | MainnetZkAndTeeVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | MainnetZkAndTeeVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | MainnetZkAndTeeVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | MainnetZkAndTeeVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | MainnetZkAndTeeVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | MainnetZkAndTeeVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | MainnetZkAndTeeVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | MainnetZkAndTeeVerifier |
| \_\_gap                     | uint256[50]        | 301  | 0      | 1600  | MainnetZkAndTeeVerifier |

## MainnetTeeAnyVerifier

| Name                        | Type               | Slot | Offset | Bytes | Contract              |
| --------------------------- | ------------------ | ---- | ------ | ----- | --------------------- |
| \_initialized               | uint8              | 0    | 0      | 1     | MainnetTeeAnyVerifier |
| \_initializing              | bool               | 0    | 1      | 1     | MainnetTeeAnyVerifier |
| \_\_gap                     | uint256[50]        | 1    | 0      | 1600  | MainnetTeeAnyVerifier |
| \_owner                     | address            | 51   | 0      | 20    | MainnetTeeAnyVerifier |
| \_\_gap                     | uint256[49]        | 52   | 0      | 1568  | MainnetTeeAnyVerifier |
| \_pendingOwner              | address            | 101  | 0      | 20    | MainnetTeeAnyVerifier |
| \_\_gap                     | uint256[49]        | 102  | 0      | 1568  | MainnetTeeAnyVerifier |
| resolver                    | contract IResolver | 151  | 0      | 20    | MainnetTeeAnyVerifier |
| \_\_gap_old_AddressResolver | uint256[49]        | 152  | 0      | 1568  | MainnetTeeAnyVerifier |
| \_\_reentry                 | uint8              | 201  | 0      | 1     | MainnetTeeAnyVerifier |
| \_\_paused                  | uint8              | 201  | 1      | 1     | MainnetTeeAnyVerifier |
| \_\_lastUnpausedAt          | uint64             | 201  | 2      | 8     | MainnetTeeAnyVerifier |
| \_\_gap                     | uint256[49]        | 202  | 0      | 1568  | MainnetTeeAnyVerifier |
| \_\_gap                     | uint256[50]        | 251  | 0      | 1600  | MainnetTeeAnyVerifier |
| \_\_gap                     | uint256[50]        | 301  | 0      | 1600  | MainnetTeeAnyVerifier |

## MainnetGuardianProver

| Name                        | Type                                            | Slot | Offset | Bytes | Contract              |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | --------------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | MainnetGuardianProver |
| \_initializing              | bool                                            | 0    | 1      | 1     | MainnetGuardianProver |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | MainnetGuardianProver |
| \_owner                     | address                                         | 51   | 0      | 20    | MainnetGuardianProver |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | MainnetGuardianProver |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | MainnetGuardianProver |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | MainnetGuardianProver |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | MainnetGuardianProver |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | MainnetGuardianProver |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | MainnetGuardianProver |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | MainnetGuardianProver |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | MainnetGuardianProver |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | MainnetGuardianProver |
| guardianIds                 | mapping(address => uint256)                     | 251  | 0      | 32    | MainnetGuardianProver |
| approvals                   | mapping(uint256 => mapping(bytes32 => uint256)) | 252  | 0      | 32    | MainnetGuardianProver |
| guardians                   | address[]                                       | 253  | 0      | 32    | MainnetGuardianProver |
| version                     | uint32                                          | 254  | 0      | 4     | MainnetGuardianProver |
| minGuardians                | uint32                                          | 254  | 4      | 4     | MainnetGuardianProver |
| provingAutoPauseEnabled     | bool                                            | 254  | 8      | 1     | MainnetGuardianProver |
| latestProofHash             | mapping(uint256 => mapping(uint256 => bytes32)) | 255  | 0      | 32    | MainnetGuardianProver |
| \_\_gap                     | uint256[45]                                     | 256  | 0      | 1440  | MainnetGuardianProver |

## MainnetTaikoL1

| Name                        | Type                   | Slot | Offset | Bytes | Contract       |
| --------------------------- | ---------------------- | ---- | ------ | ----- | -------------- |
| \_initialized               | uint8                  | 0    | 0      | 1     | MainnetTaikoL1 |
| \_initializing              | bool                   | 0    | 1      | 1     | MainnetTaikoL1 |
| \_\_gap                     | uint256[50]            | 1    | 0      | 1600  | MainnetTaikoL1 |
| \_owner                     | address                | 51   | 0      | 20    | MainnetTaikoL1 |
| \_\_gap                     | uint256[49]            | 52   | 0      | 1568  | MainnetTaikoL1 |
| \_pendingOwner              | address                | 101  | 0      | 20    | MainnetTaikoL1 |
| \_\_gap                     | uint256[49]            | 102  | 0      | 1568  | MainnetTaikoL1 |
| resolver                    | contract IResolver     | 151  | 0      | 20    | MainnetTaikoL1 |
| \_\_gap_old_AddressResolver | uint256[49]            | 152  | 0      | 1568  | MainnetTaikoL1 |
| \_\_reentry                 | uint8                  | 201  | 0      | 1     | MainnetTaikoL1 |
| \_\_paused                  | uint8                  | 201  | 1      | 1     | MainnetTaikoL1 |
| \_\_lastUnpausedAt          | uint64                 | 201  | 2      | 8     | MainnetTaikoL1 |
| \_\_gap                     | uint256[49]            | 202  | 0      | 1568  | MainnetTaikoL1 |
| state                       | struct TaikoData.State | 251  | 0      | 1600  | MainnetTaikoL1 |
| \_\_gap                     | uint256[50]            | 301  | 0      | 1600  | MainnetTaikoL1 |

## MainnetRollupDefaultResolver

| Name                        | Type                                            | Slot | Offset | Bytes | Contract                     |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ---------------------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | MainnetRollupDefaultResolver |
| \_initializing              | bool                                            | 0    | 1      | 1     | MainnetRollupDefaultResolver |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | MainnetRollupDefaultResolver |
| \_owner                     | address                                         | 51   | 0      | 20    | MainnetRollupDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | MainnetRollupDefaultResolver |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | MainnetRollupDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | MainnetRollupDefaultResolver |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | MainnetRollupDefaultResolver |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | MainnetRollupDefaultResolver |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | MainnetRollupDefaultResolver |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | MainnetRollupDefaultResolver |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | MainnetRollupDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | MainnetRollupDefaultResolver |
| \_\_addresses               | mapping(uint256 => mapping(bytes32 => address)) | 251  | 0      | 32    | MainnetRollupDefaultResolver |
| \_\_gap                     | uint256[49]                                     | 252  | 0      | 1568  | MainnetRollupDefaultResolver |

## MainnetTierRouter

| Name | Type | Slot | Offset | Bytes | Contract |
| ---- | ---- | ---- | ------ | ----- | -------- |

## MainnetProverSet

| Name                        | Type                     | Slot | Offset | Bytes | Contract         |
| --------------------------- | ------------------------ | ---- | ------ | ----- | ---------------- |
| \_initialized               | uint8                    | 0    | 0      | 1     | MainnetProverSet |
| \_initializing              | bool                     | 0    | 1      | 1     | MainnetProverSet |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | MainnetProverSet |
| \_owner                     | address                  | 51   | 0      | 20    | MainnetProverSet |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | MainnetProverSet |
| \_pendingOwner              | address                  | 101  | 0      | 20    | MainnetProverSet |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | MainnetProverSet |
| resolver                    | contract IResolver       | 151  | 0      | 20    | MainnetProverSet |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | MainnetProverSet |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | MainnetProverSet |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | MainnetProverSet |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | MainnetProverSet |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | MainnetProverSet |
| isProver                    | mapping(address => bool) | 251  | 0      | 32    | MainnetProverSet |
| admin                       | address                  | 252  | 0      | 20    | MainnetProverSet |
| \_\_gap                     | uint256[48]              | 253  | 0      | 1536  | MainnetProverSet |

## TokenUnlock

| Name                        | Type                     | Slot | Offset | Bytes | Contract    |
| --------------------------- | ------------------------ | ---- | ------ | ----- | ----------- |
| \_initialized               | uint8                    | 0    | 0      | 1     | TokenUnlock |
| \_initializing              | bool                     | 0    | 1      | 1     | TokenUnlock |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | TokenUnlock |
| \_owner                     | address                  | 51   | 0      | 20    | TokenUnlock |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | TokenUnlock |
| \_pendingOwner              | address                  | 101  | 0      | 20    | TokenUnlock |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | TokenUnlock |
| resolver                    | contract IResolver       | 151  | 0      | 20    | TokenUnlock |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | TokenUnlock |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | TokenUnlock |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | TokenUnlock |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | TokenUnlock |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | TokenUnlock |
| amountVested                | uint256                  | 251  | 0      | 32    | TokenUnlock |
| recipient                   | address                  | 252  | 0      | 20    | TokenUnlock |
| tgeTimestamp                | uint64                   | 252  | 20     | 8     | TokenUnlock |
| isProverSet                 | mapping(address => bool) | 253  | 0      | 32    | TokenUnlock |
| \_\_gap                     | uint256[47]              | 254  | 0      | 1504  | TokenUnlock |

## ProverSet

| Name                        | Type                     | Slot | Offset | Bytes | Contract  |
| --------------------------- | ------------------------ | ---- | ------ | ----- | --------- |
| \_initialized               | uint8                    | 0    | 0      | 1     | ProverSet |
| \_initializing              | bool                     | 0    | 1      | 1     | ProverSet |
| \_\_gap                     | uint256[50]              | 1    | 0      | 1600  | ProverSet |
| \_owner                     | address                  | 51   | 0      | 20    | ProverSet |
| \_\_gap                     | uint256[49]              | 52   | 0      | 1568  | ProverSet |
| \_pendingOwner              | address                  | 101  | 0      | 20    | ProverSet |
| \_\_gap                     | uint256[49]              | 102  | 0      | 1568  | ProverSet |
| resolver                    | contract IResolver       | 151  | 0      | 20    | ProverSet |
| \_\_gap_old_AddressResolver | uint256[49]              | 152  | 0      | 1568  | ProverSet |
| \_\_reentry                 | uint8                    | 201  | 0      | 1     | ProverSet |
| \_\_paused                  | uint8                    | 201  | 1      | 1     | ProverSet |
| \_\_lastUnpausedAt          | uint64                   | 201  | 2      | 8     | ProverSet |
| \_\_gap                     | uint256[49]              | 202  | 0      | 1568  | ProverSet |
| isProver                    | mapping(address => bool) | 251  | 0      | 32    | ProverSet |
| admin                       | address                  | 252  | 0      | 20    | ProverSet |
| \_\_gap                     | uint256[48]              | 253  | 0      | 1536  | ProverSet |

## GuardianProver

| Name                        | Type                                            | Slot | Offset | Bytes | Contract       |
| --------------------------- | ----------------------------------------------- | ---- | ------ | ----- | -------------- |
| \_initialized               | uint8                                           | 0    | 0      | 1     | GuardianProver |
| \_initializing              | bool                                            | 0    | 1      | 1     | GuardianProver |
| \_\_gap                     | uint256[50]                                     | 1    | 0      | 1600  | GuardianProver |
| \_owner                     | address                                         | 51   | 0      | 20    | GuardianProver |
| \_\_gap                     | uint256[49]                                     | 52   | 0      | 1568  | GuardianProver |
| \_pendingOwner              | address                                         | 101  | 0      | 20    | GuardianProver |
| \_\_gap                     | uint256[49]                                     | 102  | 0      | 1568  | GuardianProver |
| resolver                    | contract IResolver                              | 151  | 0      | 20    | GuardianProver |
| \_\_gap_old_AddressResolver | uint256[49]                                     | 152  | 0      | 1568  | GuardianProver |
| \_\_reentry                 | uint8                                           | 201  | 0      | 1     | GuardianProver |
| \_\_paused                  | uint8                                           | 201  | 1      | 1     | GuardianProver |
| \_\_lastUnpausedAt          | uint64                                          | 201  | 2      | 8     | GuardianProver |
| \_\_gap                     | uint256[49]                                     | 202  | 0      | 1568  | GuardianProver |
| guardianIds                 | mapping(address => uint256)                     | 251  | 0      | 32    | GuardianProver |
| approvals                   | mapping(uint256 => mapping(bytes32 => uint256)) | 252  | 0      | 32    | GuardianProver |
| guardians                   | address[]                                       | 253  | 0      | 32    | GuardianProver |
| version                     | uint32                                          | 254  | 0      | 4     | GuardianProver |
| minGuardians                | uint32                                          | 254  | 4      | 4     | GuardianProver |
| provingAutoPauseEnabled     | bool                                            | 254  | 8      | 1     | GuardianProver |
| latestProofHash             | mapping(uint256 => mapping(uint256 => bytes32)) | 255  | 0      | 32    | GuardianProver |
| \_\_gap                     | uint256[45]                                     | 256  | 0      | 1440  | GuardianProver |
