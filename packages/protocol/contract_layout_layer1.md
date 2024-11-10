## contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault

| Name                          | Type                                                 | Slot | Offset | Bytes | Contract                                                  |
| ----------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | --------------------------------------------------------- |
| \_initialized                 | uint8                                                | 0    | 0      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_initializing                | bool                                                 | 0    | 1      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 1    | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_owner                       | address                                              | 51   | 0      | 20    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[49]                                          | 52   | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_pendingOwner                | address                                              | 101  | 0      | 20    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[49]                                          | 102  | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_resolver                  | address                                              | 151  | 0      | 20    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gapFromOldAddressResolver | uint256[49]                                          | 152  | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_reentry                   | uint8                                                | 201  | 0      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_paused                    | uint8                                                | 201  | 1      | 1     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_lastUnpausedAt            | uint64                                               | 201  | 2      | 8     | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[49]                                          | 202  | 0      | 1568  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 251  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| bridgedToCanonical            | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| canonicalToBridged            | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[48]                                          | 303  | 0      | 1536  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 351  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 401  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 451  | 0      | 1600  | contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault |

## contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault

| Name                          | Type                                                 | Slot | Offset | Bytes | Contract                                              |
| ----------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ----------------------------------------------------- |
| \_initialized                 | uint8                                                | 0    | 0      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_initializing                | bool                                                 | 0    | 1      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap                       | uint256[50]                                          | 1    | 0      | 1600  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_owner                       | address                                              | 51   | 0      | 20    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap                       | uint256[49]                                          | 52   | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_pendingOwner                | address                                              | 101  | 0      | 20    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap                       | uint256[49]                                          | 102  | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_resolver                  | address                                              | 151  | 0      | 20    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gapFromOldAddressResolver | uint256[49]                                          | 152  | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_reentry                   | uint8                                                | 201  | 0      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_paused                    | uint8                                                | 201  | 1      | 1     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_lastUnpausedAt            | uint64                                               | 201  | 2      | 8     | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap                       | uint256[49]                                          | 202  | 0      | 1568  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap                       | uint256[50]                                          | 251  | 0      | 1600  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| bridgedToCanonical            | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| canonicalToBridged            | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| btokenDenylist                | mapping(address => bool)                             | 303  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| lastMigrationStart            | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |
| \_\_gap                       | uint256[46]                                          | 305  | 0      | 1472  | contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault |

## contracts/shared/tokenvault/ERC721Vault.soenunlock/Tol:ERC721Vault

## contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20

| Name                          | Type                                            | Slot | Offset | Bytes | Contract                                                  |
| ----------------------------- | ----------------------------------------------- | ---- | ------ | ----- | --------------------------------------------------------- |
| \_initialized                 | uint8                                           | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_initializing                | bool                                            | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap                       | uint256[50]                                     | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_owner                       | address                                         | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap                       | uint256[49]                                     | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_pendingOwner                | address                                         | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap                       | uint256[49]                                     | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_resolver                  | address                                         | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gapFromOldAddressResolver | uint256[49]                                     | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_reentry                   | uint8                                           | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_paused                    | uint8                                           | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_lastUnpausedAt            | uint64                                          | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap                       | uint256[49]                                     | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_balances                    | mapping(address => uint256)                     | 251  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_allowances                  | mapping(address => mapping(address => uint256)) | 252  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_totalSupply                 | uint256                                         | 253  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_name                        | string                                          | 254  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_symbol                      | string                                          | 255  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap                       | uint256[45]                                     | 256  | 0      | 1440  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| srcToken                      | address                                         | 301  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_srcDecimals               | uint8                                           | 301  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| srcChainId                    | uint256                                         | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| migratingAddress              | address                                         | 303  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| migratingInbound              | bool                                            | 303  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |
| \_\_gap                       | uint256[47]                                     | 304  | 0      | 1504  | contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20 |

## contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2

| Name                          | Type                                                   | Slot | Offset | Bytes | Contract                                                      |
| ----------------------------- | ------------------------------------------------------ | ---- | ------ | ----- | ------------------------------------------------------------- |
| \_initialized                 | uint8                                                  | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_initializing                | bool                                                   | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[50]                                            | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_owner                       | address                                                | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[49]                                            | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_pendingOwner                | address                                                | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[49]                                            | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_resolver                  | address                                                | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gapFromOldAddressResolver | uint256[49]                                            | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_reentry                   | uint8                                                  | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_paused                    | uint8                                                  | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_lastUnpausedAt            | uint64                                                 | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[49]                                            | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_balances                    | mapping(address => uint256)                            | 251  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_allowances                  | mapping(address => mapping(address => uint256))        | 252  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_totalSupply                 | uint256                                                | 253  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_name                        | string                                                 | 254  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_symbol                      | string                                                 | 255  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[45]                                            | 256  | 0      | 1440  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| srcToken                      | address                                                | 301  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_srcDecimals               | uint8                                                  | 301  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| srcChainId                    | uint256                                                | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| migratingAddress              | address                                                | 303  | 0      | 20    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| migratingInbound              | bool                                                   | 303  | 20     | 1     | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[47]                                            | 304  | 0      | 1504  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_hashedName                  | bytes32                                                | 351  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_hashedVersion               | bytes32                                                | 352  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_name                        | string                                                 | 353  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_version                     | string                                                 | 354  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[48]                                            | 355  | 0      | 1536  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_nonces                      | mapping(address => struct CountersUpgradeable.Counter) | 403  | 0      | 32    | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |
| \_\_gap                       | uint256[49]                                            | 404  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2 |

## contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721

| Name                          | Type                                         | Slot | Offset | Bytes | Contract                                                    |
| ----------------------------- | -------------------------------------------- | ---- | ------ | ----- | ----------------------------------------------------------- |
| \_initialized                 | uint8                                        | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_initializing                | bool                                         | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[50]                                  | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_owner                       | address                                      | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[49]                                  | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_pendingOwner                | address                                      | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[49]                                  | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_resolver                  | address                                      | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gapFromOldAddressResolver | uint256[49]                                  | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_reentry                   | uint8                                        | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_paused                    | uint8                                        | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_lastUnpausedAt            | uint64                                       | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[49]                                  | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[50]                                  | 251  | 0      | 1600  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_name                        | string                                       | 301  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_symbol                      | string                                       | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_owners                      | mapping(uint256 => address)                  | 303  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_balances                    | mapping(address => uint256)                  | 304  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_tokenApprovals              | mapping(uint256 => address)                  | 305  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_operatorApprovals           | mapping(address => mapping(address => bool)) | 306  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[44]                                  | 307  | 0      | 1408  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| srcToken                      | address                                      | 351  | 0      | 20    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| srcChainId                    | uint256                                      | 352  | 0      | 32    | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |
| \_\_gap                       | uint256[48]                                  | 353  | 0      | 1536  | contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721 |

## contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155

| Name                          | Type                                            | Slot | Offset | Bytes | Contract                                                      |
| ----------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ------------------------------------------------------------- |
| \_initialized                 | uint8                                           | 0    | 0      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_initializing                | bool                                            | 0    | 1      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[50]                                     | 1    | 0      | 1600  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_owner                       | address                                         | 51   | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[49]                                     | 52   | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_pendingOwner                | address                                         | 101  | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[49]                                     | 102  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_resolver                  | address                                         | 151  | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gapFromOldAddressResolver | uint256[49]                                     | 152  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_reentry                   | uint8                                           | 201  | 0      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_paused                    | uint8                                           | 201  | 1      | 1     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_lastUnpausedAt            | uint64                                          | 201  | 2      | 8     | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[49]                                     | 202  | 0      | 1568  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[50]                                     | 251  | 0      | 1600  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_balances                    | mapping(uint256 => mapping(address => uint256)) | 301  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_operatorApprovals           | mapping(address => mapping(address => bool))    | 302  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_uri                         | string                                          | 303  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[47]                                     | 304  | 0      | 1504  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| srcToken                      | address                                         | 351  | 0      | 20    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| srcChainId                    | uint256                                         | 352  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| symbol                        | string                                          | 353  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| name                          | string                                          | 354  | 0      | 32    | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |
| \_\_gap                       | uint256[46]                                     | 355  | 0      | 1472  | contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155 |

## contracts/shared/bridge/Bridge.sol:Bridge

| Name                          | Type                                    | Slot | Offset | Bytes | Contract                                  |
| ----------------------------- | --------------------------------------- | ---- | ------ | ----- | ----------------------------------------- |
| \_initialized                 | uint8                                   | 0    | 0      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| \_initializing                | bool                                    | 0    | 1      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_gap                       | uint256[50]                             | 1    | 0      | 1600  | contracts/shared/bridge/Bridge.sol:Bridge |
| \_owner                       | address                                 | 51   | 0      | 20    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_gap                       | uint256[49]                             | 52   | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| \_pendingOwner                | address                                 | 101  | 0      | 20    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_gap                       | uint256[49]                             | 102  | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_resolver                  | address                                 | 151  | 0      | 20    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_gapFromOldAddressResolver | uint256[49]                             | 152  | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_reentry                   | uint8                                   | 201  | 0      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_paused                    | uint8                                   | 201  | 1      | 1     | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_lastUnpausedAt            | uint64                                  | 201  | 2      | 8     | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_gap                       | uint256[49]                             | 202  | 0      | 1568  | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_reserved1                 | uint64                                  | 251  | 0      | 8     | contracts/shared/bridge/Bridge.sol:Bridge |
| nextMessageId                 | uint64                                  | 251  | 8      | 8     | contracts/shared/bridge/Bridge.sol:Bridge |
| messageStatus                 | mapping(bytes32 => enum IBridge.Status) | 252  | 0      | 32    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_ctx                       | struct IBridge.Context                  | 253  | 0      | 64    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_reserved2                 | uint256                                 | 255  | 0      | 32    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_reserved3                 | uint256                                 | 256  | 0      | 32    | contracts/shared/bridge/Bridge.sol:Bridge |
| \_\_gap                       | uint256[44]                             | 257  | 0      | 1408  | contracts/shared/bridge/Bridge.sol:Bridge |

## contracts/shared/bridge/QuotaManager.sol:QuotaManager

| Name                          | Type                                          | Slot | Offset | Bytes | Contract                                              |
| ----------------------------- | --------------------------------------------- | ---- | ------ | ----- | ----------------------------------------------------- |
| \_initialized                 | uint8                                         | 0    | 0      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_initializing                | bool                                          | 0    | 1      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_gap                       | uint256[50]                                   | 1    | 0      | 1600  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_owner                       | address                                       | 51   | 0      | 20    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_gap                       | uint256[49]                                   | 52   | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_pendingOwner                | address                                       | 101  | 0      | 20    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_gap                       | uint256[49]                                   | 102  | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_resolver                  | address                                       | 151  | 0      | 20    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_gapFromOldAddressResolver | uint256[49]                                   | 152  | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_reentry                   | uint8                                         | 201  | 0      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_paused                    | uint8                                         | 201  | 1      | 1     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_lastUnpausedAt            | uint64                                        | 201  | 2      | 8     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_gap                       | uint256[49]                                   | 202  | 0      | 1568  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| tokenQuota                    | mapping(address => struct QuotaManager.Quota) | 251  | 0      | 32    | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| quotaPeriod                   | uint24                                        | 252  | 0      | 3     | contracts/shared/bridge/QuotaManager.sol:QuotaManager |
| \_\_gap                       | uint256[48]                                   | 253  | 0      | 1536  | contracts/shared/bridge/QuotaManager.sol:QuotaManager |

## contracts/shared/common/DefaultResolver.sol:DefaultResolver

| Name                          | Type                                            | Slot | Offset | Bytes | Contract                                                    |
| ----------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ----------------------------------------------------------- |
| \_initialized                 | uint8                                           | 0    | 0      | 1     | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_initializing                | bool                                            | 0    | 1      | 1     | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_gap                       | uint256[50]                                     | 1    | 0      | 1600  | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_owner                       | address                                         | 51   | 0      | 20    | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_gap                       | uint256[49]                                     | 52   | 0      | 1568  | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_pendingOwner                | address                                         | 101  | 0      | 20    | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_gap                       | uint256[49]                                     | 102  | 0      | 1568  | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_resolver                  | address                                         | 151  | 0      | 20    | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_gapFromOldAddressResolver | uint256[49]                                     | 152  | 0      | 1568  | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_reentry                   | uint8                                           | 201  | 0      | 1     | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_paused                    | uint8                                           | 201  | 1      | 1     | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_lastUnpausedAt            | uint64                                          | 201  | 2      | 8     | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_gap                       | uint256[49]                                     | 202  | 0      | 1568  | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_addresses                 | mapping(uint256 => mapping(bytes32 => address)) | 251  | 0      | 32    | contracts/shared/common/DefaultResolver.sol:DefaultResolver |
| \_\_gap                       | uint256[49]                                     | 252  | 0      | 1568  | contracts/shared/common/DefaultResolver.sol:DefaultResolver |

## contracts/shared/common/EssentialContract.sol:EssentialContract

| Name                          | Type        | Slot | Offset | Bytes | Contract                                                        |
| ----------------------------- | ----------- | ---- | ------ | ----- | --------------------------------------------------------------- |
| \_initialized                 | uint8       | 0    | 0      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_initializing                | bool        | 0    | 1      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_gap                       | uint256[50] | 1    | 0      | 1600  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_owner                       | address     | 51   | 0      | 20    | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_gap                       | uint256[49] | 52   | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_pendingOwner                | address     | 101  | 0      | 20    | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_gap                       | uint256[49] | 102  | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_resolver                  | address     | 151  | 0      | 20    | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_gapFromOldAddressResolver | uint256[49] | 152  | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_reentry                   | uint8       | 201  | 0      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_paused                    | uint8       | 201  | 1      | 1     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_lastUnpausedAt            | uint64      | 201  | 2      | 8     | contracts/shared/common/EssentialContract.sol:EssentialContract |
| \_\_gap                       | uint256[49] | 202  | 0      | 1568  | contracts/shared/common/EssentialContract.sol:EssentialContract |

## contracts/shared/signal/SignalService.sol:SignalService

| Name                          | Type                                          | Slot | Offset | Bytes | Contract                                                |
| ----------------------------- | --------------------------------------------- | ---- | ------ | ----- | ------------------------------------------------------- |
| \_initialized                 | uint8                                         | 0    | 0      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| \_initializing                | bool                                          | 0    | 1      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_gap                       | uint256[50]                                   | 1    | 0      | 1600  | contracts/shared/signal/SignalService.sol:SignalService |
| \_owner                       | address                                       | 51   | 0      | 20    | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_gap                       | uint256[49]                                   | 52   | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| \_pendingOwner                | address                                       | 101  | 0      | 20    | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_gap                       | uint256[49]                                   | 102  | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_resolver                  | address                                       | 151  | 0      | 20    | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_gapFromOldAddressResolver | uint256[49]                                   | 152  | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_reentry                   | uint8                                         | 201  | 0      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_paused                    | uint8                                         | 201  | 1      | 1     | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_lastUnpausedAt            | uint64                                        | 201  | 2      | 8     | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_gap                       | uint256[49]                                   | 202  | 0      | 1568  | contracts/shared/signal/SignalService.sol:SignalService |
| topBlockId                    | mapping(uint64 => mapping(bytes32 => uint64)) | 251  | 0      | 32    | contracts/shared/signal/SignalService.sol:SignalService |
| isAuthorized                  | mapping(address => bool)                      | 252  | 0      | 32    | contracts/shared/signal/SignalService.sol:SignalService |
| \_\_gap                       | uint256[48]                                   | 253  | 0      | 1536  | contracts/shared/signal/SignalService.sol:SignalService |

## contracts/layer1/token/TaikoToken.sol:TaikoToken

| Name                                                  | Type                                                          | Slot | Offset | Bytes | Contract                                         |
| ----------------------------------------------------- | ------------------------------------------------------------- | ---- | ------ | ----- | ------------------------------------------------ |
| \_initialized                                         | uint8                                                         | 0    | 0      | 1     | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_initializing                                        | bool                                                          | 0    | 1      | 1     | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[50]                                                   | 1    | 0      | 1600  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_owner                                               | address                                                       | 51   | 0      | 20    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 52   | 0      | 1568  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_pendingOwner                                        | address                                                       | 101  | 0      | 20    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 102  | 0      | 1568  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_resolver                                          | address                                                       | 151  | 0      | 20    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gapFromOldAddressResolver                         | uint256[49]                                                   | 152  | 0      | 1568  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_reentry                                           | uint8                                                         | 201  | 0      | 1     | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_paused                                            | uint8                                                         | 201  | 1      | 1     | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_lastUnpausedAt                                    | uint64                                                        | 201  | 2      | 8     | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 202  | 0      | 1568  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_slots_previously_used_by_ERC20SnapshotUpgradeable | uint256[50]                                                   | 251  | 0      | 1600  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_balances                                            | mapping(address => uint256)                                   | 301  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_allowances                                          | mapping(address => mapping(address => uint256))               | 302  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_totalSupply                                         | uint256                                                       | 303  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_name                                                | string                                                        | 304  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_symbol                                              | string                                                        | 305  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[45]                                                   | 306  | 0      | 1440  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_hashedName                                          | bytes32                                                       | 351  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_hashedVersion                                       | bytes32                                                       | 352  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_name                                                | string                                                        | 353  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_version                                             | string                                                        | 354  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[48]                                                   | 355  | 0      | 1536  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_nonces                                              | mapping(address => struct CountersUpgradeable.Counter)        | 403  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_PERMIT_TYPEHASH_DEPRECATED_SLOT                     | bytes32                                                       | 404  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[49]                                                   | 405  | 0      | 1568  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_delegates                                           | mapping(address => address)                                   | 454  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_checkpoints                                         | mapping(address => struct ERC20VotesUpgradeable.Checkpoint[]) | 455  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_totalSupplyCheckpoints                              | struct ERC20VotesUpgradeable.Checkpoint[]                     | 456  | 0      | 32    | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[47]                                                   | 457  | 0      | 1504  | contracts/layer1/token/TaikoToken.sol:TaikoToken |
| \_\_gap                                               | uint256[50]                                                   | 504  | 0      | 1600  | contracts/layer1/token/TaikoToken.sol:TaikoToken |

## contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier

| Name                          | Type        | Slot | Offset | Bytes | Contract                                                               |
| ----------------------------- | ----------- | ---- | ------ | ----- | ---------------------------------------------------------------------- |
| \_initialized                 | uint8       | 0    | 0      | 1     | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_initializing                | bool        | 0    | 1      | 1     | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_gap                       | uint256[50] | 1    | 0      | 1600  | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_owner                       | address     | 51   | 0      | 20    | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_gap                       | uint256[49] | 52   | 0      | 1568  | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_pendingOwner                | address     | 101  | 0      | 20    | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_gap                       | uint256[49] | 102  | 0      | 1568  | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_resolver                  | address     | 151  | 0      | 20    | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_gapFromOldAddressResolver | uint256[49] | 152  | 0      | 1568  | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_reentry                   | uint8       | 201  | 0      | 1     | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_paused                    | uint8       | 201  | 1      | 1     | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_lastUnpausedAt            | uint64      | 201  | 2      | 8     | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_gap                       | uint256[49] | 202  | 0      | 1568  | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |
| \_\_gap                       | uint256[50] | 251  | 0      | 1600  | contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier |

## contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier

| Name                          | Type        | Slot | Offset | Bytes | Contract                                                             |
| ----------------------------- | ----------- | ---- | ------ | ----- | -------------------------------------------------------------------- |
| \_initialized                 | uint8       | 0    | 0      | 1     | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_initializing                | bool        | 0    | 1      | 1     | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gap                       | uint256[50] | 1    | 0      | 1600  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_owner                       | address     | 51   | 0      | 20    | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gap                       | uint256[49] | 52   | 0      | 1568  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_pendingOwner                | address     | 101  | 0      | 20    | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gap                       | uint256[49] | 102  | 0      | 1568  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_resolver                  | address     | 151  | 0      | 20    | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gapFromOldAddressResolver | uint256[49] | 152  | 0      | 1568  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_reentry                   | uint8       | 201  | 0      | 1     | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_paused                    | uint8       | 201  | 1      | 1     | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_lastUnpausedAt            | uint64      | 201  | 2      | 8     | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gap                       | uint256[49] | 202  | 0      | 1568  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gap                       | uint256[50] | 251  | 0      | 1600  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |
| \_\_gap                       | uint256[50] | 301  | 0      | 1600  | contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier |

## contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier

| Name                          | Type        | Slot | Offset | Bytes | Contract                                                                 |
| ----------------------------- | ----------- | ---- | ------ | ----- | ------------------------------------------------------------------------ |
| \_initialized                 | uint8       | 0    | 0      | 1     | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_initializing                | bool        | 0    | 1      | 1     | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gap                       | uint256[50] | 1    | 0      | 1600  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_owner                       | address     | 51   | 0      | 20    | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gap                       | uint256[49] | 52   | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_pendingOwner                | address     | 101  | 0      | 20    | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gap                       | uint256[49] | 102  | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_resolver                  | address     | 151  | 0      | 20    | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gapFromOldAddressResolver | uint256[49] | 152  | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_reentry                   | uint8       | 201  | 0      | 1     | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_paused                    | uint8       | 201  | 1      | 1     | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_lastUnpausedAt            | uint64      | 201  | 2      | 8     | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gap                       | uint256[49] | 202  | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gap                       | uint256[50] | 251  | 0      | 1600  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |
| \_\_gap                       | uint256[50] | 301  | 0      | 1600  | contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier |

## contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier

| Name                          | Type        | Slot | Offset | Bytes | Contract                                                           |
| ----------------------------- | ----------- | ---- | ------ | ----- | ------------------------------------------------------------------ |
| \_initialized                 | uint8       | 0    | 0      | 1     | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_initializing                | bool        | 0    | 1      | 1     | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gap                       | uint256[50] | 1    | 0      | 1600  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_owner                       | address     | 51   | 0      | 20    | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gap                       | uint256[49] | 52   | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_pendingOwner                | address     | 101  | 0      | 20    | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gap                       | uint256[49] | 102  | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_resolver                  | address     | 151  | 0      | 20    | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gapFromOldAddressResolver | uint256[49] | 152  | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_reentry                   | uint8       | 201  | 0      | 1     | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_paused                    | uint8       | 201  | 1      | 1     | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_lastUnpausedAt            | uint64      | 201  | 2      | 8     | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gap                       | uint256[49] | 202  | 0      | 1568  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gap                       | uint256[50] | 251  | 0      | 1600  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |
| \_\_gap                       | uint256[50] | 301  | 0      | 1600  | contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier |

## contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier

| Name                          | Type                     | Slot | Offset | Bytes | Contract                                                   |
| ----------------------------- | ------------------------ | ---- | ------ | ----- | ---------------------------------------------------------- |
| \_initialized                 | uint8                    | 0    | 0      | 1     | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_initializing                | bool                     | 0    | 1      | 1     | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_gap                       | uint256[50]              | 1    | 0      | 1600  | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_owner                       | address                  | 51   | 0      | 20    | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_gap                       | uint256[49]              | 52   | 0      | 1568  | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_pendingOwner                | address                  | 101  | 0      | 20    | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_gap                       | uint256[49]              | 102  | 0      | 1568  | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_resolver                  | address                  | 151  | 0      | 20    | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_gapFromOldAddressResolver | uint256[49]              | 152  | 0      | 1568  | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_reentry                   | uint8                    | 201  | 0      | 1     | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_paused                    | uint8                    | 201  | 1      | 1     | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_lastUnpausedAt            | uint64                   | 201  | 2      | 8     | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_gap                       | uint256[49]              | 202  | 0      | 1568  | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| isImageTrusted                | mapping(bytes32 => bool) | 251  | 0      | 32    | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |
| \_\_gap                       | uint256[49]              | 252  | 0      | 1568  | contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier |

## contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier

| Name                          | Type                     | Slot | Offset | Bytes | Contract                                               |
| ----------------------------- | ------------------------ | ---- | ------ | ----- | ------------------------------------------------------ |
| \_initialized                 | uint8                    | 0    | 0      | 1     | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_initializing                | bool                     | 0    | 1      | 1     | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_gap                       | uint256[50]              | 1    | 0      | 1600  | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_owner                       | address                  | 51   | 0      | 20    | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_gap                       | uint256[49]              | 52   | 0      | 1568  | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_pendingOwner                | address                  | 101  | 0      | 20    | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_gap                       | uint256[49]              | 102  | 0      | 1568  | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_resolver                  | address                  | 151  | 0      | 20    | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_gapFromOldAddressResolver | uint256[49]              | 152  | 0      | 1568  | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_reentry                   | uint8                    | 201  | 0      | 1     | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_paused                    | uint8                    | 201  | 1      | 1     | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_lastUnpausedAt            | uint64                   | 201  | 2      | 8     | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_gap                       | uint256[49]              | 202  | 0      | 1568  | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| isProgramTrusted              | mapping(bytes32 => bool) | 251  | 0      | 32    | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |
| \_\_gap                       | uint256[49]              | 252  | 0      | 1568  | contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier |

## contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier

| Name                          | Type                                            | Slot | Offset | Bytes | Contract                                               |
| ----------------------------- | ----------------------------------------------- | ---- | ------ | ----- | ------------------------------------------------------ |
| \_initialized                 | uint8                                           | 0    | 0      | 1     | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_initializing                | bool                                            | 0    | 1      | 1     | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_gap                       | uint256[50]                                     | 1    | 0      | 1600  | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_owner                       | address                                         | 51   | 0      | 20    | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_gap                       | uint256[49]                                     | 52   | 0      | 1568  | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_pendingOwner                | address                                         | 101  | 0      | 20    | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_gap                       | uint256[49]                                     | 102  | 0      | 1568  | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_resolver                  | address                                         | 151  | 0      | 20    | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_gapFromOldAddressResolver | uint256[49]                                     | 152  | 0      | 1568  | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_reentry                   | uint8                                           | 201  | 0      | 1     | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_paused                    | uint8                                           | 201  | 1      | 1     | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_lastUnpausedAt            | uint64                                          | 201  | 2      | 8     | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_gap                       | uint256[49]                                     | 202  | 0      | 1568  | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| nextInstanceId                | uint256                                         | 251  | 0      | 32    | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| instances                     | mapping(uint256 => struct SgxVerifier.Instance) | 252  | 0      | 32    | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| addressRegistered             | mapping(address => bool)                        | 253  | 0      | 32    | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |
| \_\_gap                       | uint256[47]                                     | 254  | 0      | 1504  | contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier |

## contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation

| Name                          | Type                                            | Slot | Offset | Bytes | Contract                                                                                      |
| ----------------------------- | ----------------------------------------------- | ---- | ------ | ----- | --------------------------------------------------------------------------------------------- |
| \_initialized                 | uint8                                           | 0    | 0      | 1     | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_initializing                | bool                                            | 0    | 1      | 1     | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_gap                       | uint256[50]                                     | 1    | 0      | 1600  | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_owner                       | address                                         | 51   | 0      | 20    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_gap                       | uint256[49]                                     | 52   | 0      | 1568  | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_pendingOwner                | address                                         | 101  | 0      | 20    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_gap                       | uint256[49]                                     | 102  | 0      | 1568  | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_resolver                  | address                                         | 151  | 0      | 20    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_gapFromOldAddressResolver | uint256[49]                                     | 152  | 0      | 1568  | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_reentry                   | uint8                                           | 201  | 0      | 1     | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_paused                    | uint8                                           | 201  | 1      | 1     | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_lastUnpausedAt            | uint64                                          | 201  | 2      | 8     | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_gap                       | uint256[49]                                     | 202  | 0      | 1568  | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| sigVerifyLib                  | contract ISigVerifyLib                          | 251  | 0      | 20    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| pemCertLib                    | contract IPEMCertChainLib                       | 252  | 0      | 20    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| checkLocalEnclaveReport       | bool                                            | 252  | 20     | 1     | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| trustedUserMrEnclave          | mapping(bytes32 => bool)                        | 253  | 0      | 32    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| trustedUserMrSigner           | mapping(bytes32 => bool)                        | 254  | 0      | 32    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| serialNumIsRevoked            | mapping(uint256 => mapping(bytes => bool))      | 255  | 0      | 32    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| tcbInfo                       | mapping(string => struct TCBInfoStruct.TCBInfo) | 256  | 0      | 32    | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| qeIdentity                    | struct EnclaveIdStruct.EnclaveId                | 257  | 0      | 128   | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |
| \_\_gap                       | uint256[39]                                     | 261  | 0      | 1248  | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation |

## contracts/layer1/based/TaikoL1.sol:TaikoL1

| Name                          | Type                   | Slot | Offset | Bytes | Contract                                   |
| ----------------------------- | ---------------------- | ---- | ------ | ----- | ------------------------------------------ |
| \_initialized                 | uint8                  | 0    | 0      | 1     | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_initializing                | bool                   | 0    | 1      | 1     | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_gap                       | uint256[50]            | 1    | 0      | 1600  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_owner                       | address                | 51   | 0      | 20    | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_gap                       | uint256[49]            | 52   | 0      | 1568  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_pendingOwner                | address                | 101  | 0      | 20    | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_gap                       | uint256[49]            | 102  | 0      | 1568  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_resolver                  | address                | 151  | 0      | 20    | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_gapFromOldAddressResolver | uint256[49]            | 152  | 0      | 1568  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_reentry                   | uint8                  | 201  | 0      | 1     | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_paused                    | uint8                  | 201  | 1      | 1     | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_lastUnpausedAt            | uint64                 | 201  | 2      | 8     | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_gap                       | uint256[49]            | 202  | 0      | 1568  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| state                         | struct TaikoData.State | 251  | 0      | 1600  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |
| \_\_gap                       | uint256[50]            | 301  | 0      | 1600  | contracts/layer1/based/TaikoL1.sol:TaikoL1 |

## contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1

| Name                          | Type                   | Slot | Offset | Bytes | Contract                                             |
| ----------------------------- | ---------------------- | ---- | ------ | ----- | ---------------------------------------------------- |
| \_initialized                 | uint8                  | 0    | 0      | 1     | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_initializing                | bool                   | 0    | 1      | 1     | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_gap                       | uint256[50]            | 1    | 0      | 1600  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_owner                       | address                | 51   | 0      | 20    | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_gap                       | uint256[49]            | 52   | 0      | 1568  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_pendingOwner                | address                | 101  | 0      | 20    | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_gap                       | uint256[49]            | 102  | 0      | 1568  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_resolver                  | address                | 151  | 0      | 20    | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_gapFromOldAddressResolver | uint256[49]            | 152  | 0      | 1568  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_reentry                   | uint8                  | 201  | 0      | 1     | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_paused                    | uint8                  | 201  | 1      | 1     | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_lastUnpausedAt            | uint64                 | 201  | 2      | 8     | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_gap                       | uint256[49]            | 202  | 0      | 1568  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| state                         | struct TaikoData.State | 251  | 0      | 1600  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |
| \_\_gap                       | uint256[50]            | 301  | 0      | 1600  | contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1 |

## contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge

| Name                          | Type                                    | Slot | Offset | Bytes | Contract                                                             |
| ----------------------------- | --------------------------------------- | ---- | ------ | ----- | -------------------------------------------------------------------- |
| \_initialized                 | uint8                                   | 0    | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_initializing                | bool                                    | 0    | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_gap                       | uint256[50]                             | 1    | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_owner                       | address                                 | 51   | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_gap                       | uint256[49]                             | 52   | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_pendingOwner                | address                                 | 101  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_gap                       | uint256[49]                             | 102  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_resolver                  | address                                 | 151  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_gapFromOldAddressResolver | uint256[49]                             | 152  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_reentry                   | uint8                                   | 201  | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_paused                    | uint8                                   | 201  | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_lastUnpausedAt            | uint64                                  | 201  | 2      | 8     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_gap                       | uint256[49]                             | 202  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_reserved1                 | uint64                                  | 251  | 0      | 8     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| nextMessageId                 | uint64                                  | 251  | 8      | 8     | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| messageStatus                 | mapping(bytes32 => enum IBridge.Status) | 252  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_ctx                       | struct IBridge.Context                  | 253  | 0      | 64    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_reserved2                 | uint256                                 | 255  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_reserved3                 | uint256                                 | 256  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |
| \_\_gap                       | uint256[44]                             | 257  | 0      | 1408  | contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge |

## contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService

| Name                          | Type                                          | Slot | Offset | Bytes | Contract                                                                           |
| ----------------------------- | --------------------------------------------- | ---- | ------ | ----- | ---------------------------------------------------------------------------------- |
| \_initialized                 | uint8                                         | 0    | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_initializing                | bool                                          | 0    | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_gap                       | uint256[50]                                   | 1    | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_owner                       | address                                       | 51   | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_gap                       | uint256[49]                                   | 52   | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_pendingOwner                | address                                       | 101  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_gap                       | uint256[49]                                   | 102  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_resolver                  | address                                       | 151  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_gapFromOldAddressResolver | uint256[49]                                   | 152  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_reentry                   | uint8                                         | 201  | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_paused                    | uint8                                         | 201  | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_lastUnpausedAt            | uint64                                        | 201  | 2      | 8     | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_gap                       | uint256[49]                                   | 202  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| topBlockId                    | mapping(uint64 => mapping(bytes32 => uint64)) | 251  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| isAuthorized                  | mapping(address => bool)                      | 252  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |
| \_\_gap                       | uint256[48]                                   | 253  | 0      | 1536  | contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService |

## contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault

| Name                          | Type                                                 | Slot | Offset | Bytes | Contract                                                                     |
| ----------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | ---------------------------------------------------------------------------- |
| \_initialized                 | uint8                                                | 0    | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_initializing                | bool                                                 | 0    | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gap                       | uint256[50]                                          | 1    | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_owner                       | address                                              | 51   | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gap                       | uint256[49]                                          | 52   | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_pendingOwner                | address                                              | 101  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gap                       | uint256[49]                                          | 102  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_resolver                  | address                                              | 151  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gapFromOldAddressResolver | uint256[49]                                          | 152  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_reentry                   | uint8                                                | 201  | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_paused                    | uint8                                                | 201  | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_lastUnpausedAt            | uint64                                               | 201  | 2      | 8     | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gap                       | uint256[49]                                          | 202  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gap                       | uint256[50]                                          | 251  | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| bridgedToCanonical            | mapping(address => struct ERC20Vault.CanonicalERC20) | 301  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| canonicalToBridged            | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| btokenDenylist                | mapping(address => bool)                             | 303  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| lastMigrationStart            | mapping(uint256 => mapping(address => uint256))      | 304  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |
| \_\_gap                       | uint256[46]                                          | 305  | 0      | 1472  | contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault |

## contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault

| Name                          | Type                                                 | Slot | Offset | Bytes | Contract                                                                         |
| ----------------------------- | ---------------------------------------------------- | ---- | ------ | ----- | -------------------------------------------------------------------------------- |
| \_initialized                 | uint8                                                | 0    | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_initializing                | bool                                                 | 0    | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 1    | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_owner                       | address                                              | 51   | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[49]                                          | 52   | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_pendingOwner                | address                                              | 101  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[49]                                          | 102  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_resolver                  | address                                              | 151  | 0      | 20    | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gapFromOldAddressResolver | uint256[49]                                          | 152  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_reentry                   | uint8                                                | 201  | 0      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_paused                    | uint8                                                | 201  | 1      | 1     | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_lastUnpausedAt            | uint64                                               | 201  | 2      | 8     | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[49]                                          | 202  | 0      | 1568  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 251  | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| bridgedToCanonical            | mapping(address => struct BaseNFTVault.CanonicalNFT) | 301  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| canonicalToBridged            | mapping(uint256 => mapping(address => address))      | 302  | 0      | 32    | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[48]                                          | 303  | 0      | 1536  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 351  | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 401  | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |
| \_\_gap                       | uint256[50]                                          | 451  | 0      | 1600  | contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault |

## contracts/layer1/mainnet/multirollup/MainnetERC721Vault.sol:MainnetERC721Vault
