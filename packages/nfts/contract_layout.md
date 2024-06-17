## MerkleWhitelist

| Name      | Type                       | Slot | Offset | Bytes | Contract                                               |
| --------- | -------------------------- | ---- | ------ | ----- | ------------------------------------------------------ |
| root      | bytes32                    | 0    | 0      | 32    | contracts/snaefell/MerkleWhitelist.sol:MerkleWhitelist |
| minted    | mapping(bytes32 => bool)   | 1    | 0      | 32    | contracts/snaefell/MerkleWhitelist.sol:MerkleWhitelist |
| blacklist | contract IMinimalBlacklist | 2    | 0      | 20    | contracts/snaefell/MerkleWhitelist.sol:MerkleWhitelist |
| \_\_gap   | uint256[48]                | 3    | 0      | 1536  | contracts/snaefell/MerkleWhitelist.sol:MerkleWhitelist |

## TaikoonToken

| Name              | Type                       | Slot | Offset | Bytes | Contract                                        |
| ----------------- | -------------------------- | ---- | ------ | ----- | ----------------------------------------------- |
| root              | bytes32                    | 0    | 0      | 32    | contracts/taikoon/TaikoonToken.sol:TaikoonToken |
| minted            | mapping(bytes32 => bool)   | 1    | 0      | 32    | contracts/taikoon/TaikoonToken.sol:TaikoonToken |
| blacklist         | contract IMinimalBlacklist | 2    | 0      | 20    | contracts/taikoon/TaikoonToken.sol:TaikoonToken |
| \_\_gap           | uint256[47]                | 3    | 0      | 1504  | contracts/taikoon/TaikoonToken.sol:TaikoonToken |
| \_totalSupply     | uint256                    | 50   | 0      | 32    | contracts/taikoon/TaikoonToken.sol:TaikoonToken |
| \_baseURIExtended | string                     | 51   | 0      | 32    | contracts/taikoon/TaikoonToken.sol:TaikoonToken |
| \_\_gap           | uint256[47]                | 52   | 0      | 1504  | contracts/taikoon/TaikoonToken.sol:TaikoonToken |

## SnaefellToken

| Name              | Type                       | Slot | Offset | Bytes | Contract                                           |
| ----------------- | -------------------------- | ---- | ------ | ----- | -------------------------------------------------- |
| root              | bytes32                    | 0    | 0      | 32    | contracts/snaefell/SnaefellToken.sol:SnaefellToken |
| minted            | mapping(bytes32 => bool)   | 1    | 0      | 32    | contracts/snaefell/SnaefellToken.sol:SnaefellToken |
| blacklist         | contract IMinimalBlacklist | 2    | 0      | 20    | contracts/snaefell/SnaefellToken.sol:SnaefellToken |
| \_\_gap           | uint256[48]                | 3    | 0      | 1536  | contracts/snaefell/SnaefellToken.sol:SnaefellToken |
| \_totalSupply     | uint256                    | 51   | 0      | 32    | contracts/snaefell/SnaefellToken.sol:SnaefellToken |
| \_baseURIExtended | string                     | 52   | 0      | 32    | contracts/snaefell/SnaefellToken.sol:SnaefellToken |
| \_\_gap           | uint256[48]                | 53   | 0      | 1536  | contracts/snaefell/SnaefellToken.sol:SnaefellToken |

## ECDSAWhitelist

| Name       | Type                       | Slot | Offset | Bytes | Contract                                                        |
| ---------- | -------------------------- | ---- | ------ | ----- | --------------------------------------------------------------- |
| mintSigner | address                    | 0    | 0      | 20    | contracts/trailblazers-badges/ECDSAWhitelist.sol:ECDSAWhitelist |
| minted     | mapping(bytes32 => bool)   | 1    | 0      | 32    | contracts/trailblazers-badges/ECDSAWhitelist.sol:ECDSAWhitelist |
| blacklist  | contract IMinimalBlacklist | 2    | 0      | 20    | contracts/trailblazers-badges/ECDSAWhitelist.sol:ECDSAWhitelist |
| \_\_gap    | uint256[47]                | 3    | 0      | 1504  | contracts/trailblazers-badges/ECDSAWhitelist.sol:ECDSAWhitelist |

## TrailblazersBadges

| Name              | Type                                            | Slot | Offset | Bytes | Contract                                                                |
| ----------------- | ----------------------------------------------- | ---- | ------ | ----- | ----------------------------------------------------------------------- |
| mintSigner        | address                                         | 0    | 0      | 20    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| minted            | mapping(bytes32 => bool)                        | 1    | 0      | 32    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| blacklist         | contract IMinimalBlacklist                      | 2    | 0      | 20    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| \_\_gap           | uint256[47]                                     | 3    | 0      | 1504  | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| \_baseURIExtended | string                                          | 50   | 0      | 32    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| badges            | mapping(uint256 => uint256)                     | 51   | 0      | 32    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| movements         | mapping(address => uint256)                     | 52   | 0      | 32    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| userBadges        | mapping(address => mapping(uint256 => uint256)) | 53   | 0      | 32    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| movementBadges    | mapping(bytes32 => uint256[2])                  | 54   | 0      | 32    | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
| \_\_gap           | uint256[43]                                     | 55   | 0      | 1376  | contracts/trailblazers-badges/TrailblazersBadges.sol:TrailblazersBadges |
