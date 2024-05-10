// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IBridgedERC1155
/// @notice Contract for bridging ERC1155 tokens across different chains.
/// @custom:security-contact security@taiko.xyz
interface IBridgedERC1155 {
    /// @dev Mints tokens.
    /// @param _to Address to receive the minted tokens.
    /// @param _tokenIds ID of the token to mint.
    /// @param _amounts Amount of tokens to mint.
    function mintBatch(
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    )
        external;

    /// @dev Batch burns tokens.
    /// @param _ids Array of IDs of the tokens to burn.
    /// @param _amounts Amount of tokens to burn respectively.
    function burnBatch(uint256[] calldata _ids, uint256[] calldata _amounts) external;

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() external view returns (address, uint256);
}

/// @title IBridgedERC1155Initializable
/// @custom:security-contact security@taiko.xyz
interface IBridgedERC1155Initializable is IBridgedERC1155 {
    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _srcToken Address of the source token.
    /// @param _srcChainId Source chain ID.
    /// @param _symbol Symbol of the bridged token.
    /// @param _name Name of the bridged token.
    function init(
        address _owner,
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        string calldata _symbol,
        string calldata _name
    )
        external;
}
