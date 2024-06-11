// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import { MerkleWhitelist } from "./MerkleWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TaikoonToken} from "./TaikoonToken.sol";

/// @title TaikoonToken
/// @dev The Taikoons ERC-721 token
/// @custom:security-contact security@taiko.xyz
contract TaikoonTokenV2 is TaikoonToken {
    /// @notice Base URI required to interact with IPFS
    string private _baseURIExtended;
    /// @notice Update the base URI
    /// @param _rootURI The new base URI
    /// @dev Only the owner can update the base URI
    function updateBaseURI(string memory _rootURI) public onlyOwner {
        _baseURIExtended = _rootURI;
    }
}
