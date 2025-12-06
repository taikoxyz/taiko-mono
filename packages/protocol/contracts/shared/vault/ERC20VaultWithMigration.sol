// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibAddress.sol";
import "./ERC20Vault.sol";
import "./IBridgedERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./ERC20VaultWithMigration_Layout.sol"; // DO NOT DELETE

/// @title ERC20VaultWithMigration
/// @notice ERC20Vault with token migration support. This contract extends ERC20Vault
/// to add the ability to change bridged tokens with a migration mechanism.
/// @dev This contract adds migration functionality that allows the owner to change
/// the bridged token for a canonical token, enabling token migrations with a minimum
/// delay between migrations.
/// @custom:security-contact security@taiko.xyz
contract ERC20VaultWithMigration is ERC20Vault {
    using Address for address;
    using LibAddress for address;
    uint256 public constant MIN_MIGRATION_DELAY = 90 days;

    uint256[50] private __gap;

    /// @notice Emitted when a bridged token is changed.
    /// @param srcChainId The chain ID of the canonical token.
    /// @param ctoken The address of the canonical token.
    /// @param btokenOld The address of the old bridged token.
    /// @param btokenNew The address of the new bridged token.
    /// @param ctokenSymbol The symbol of the canonical token.
    /// @param ctokenName The name of the canonical token.
    /// @param ctokenDecimal The decimal of the canonical token.
    event BridgedTokenChanged(
        uint256 indexed srcChainId,
        address indexed ctoken,
        address btokenOld,
        address btokenNew,
        string ctokenSymbol,
        string ctokenName,
        uint8 ctokenDecimal
    );

    error VAULT_CTOKEN_MISMATCH();
    error VAULT_INVALID_CTOKEN();
    error VAULT_INVALID_NEW_BTOKEN();
    error VAULT_LAST_MIGRATION_TOO_CLOSE();

    constructor(address _resolver) ERC20Vault(_resolver) { }

    /// @notice Change bridged token.
    /// @param _ctoken The canonical token.
    /// @param _btokenNew The new bridged token address.
    /// @return btokenOld_ The old bridged token address.
    function changeBridgedToken(
        CanonicalERC20 calldata _ctoken,
        address _btokenNew
    )
        external
        onlyOwner
        nonReentrant
        returns (address btokenOld_)
    {
        if (
            _btokenNew == address(0) || bridgedToCanonical[_btokenNew].addr != address(0)
                || !_btokenNew.isContract()
        ) {
            revert VAULT_INVALID_NEW_BTOKEN();
        }

        if (_ctoken.addr == address(0) || _ctoken.chainId == block.chainid) {
            revert VAULT_INVALID_CTOKEN();
        }

        if (btokenDenylist[_btokenNew]) revert VAULT_BTOKEN_BLACKLISTED();

        uint256 _lastMigrationStart = lastMigrationStart[_ctoken.chainId][_ctoken.addr];
        if (block.timestamp < _lastMigrationStart + MIN_MIGRATION_DELAY) {
            revert VAULT_LAST_MIGRATION_TOO_CLOSE();
        }

        btokenOld_ = canonicalToBridged[_ctoken.chainId][_ctoken.addr];

        if (btokenOld_ != address(0)) {
            CanonicalERC20 memory ctoken = bridgedToCanonical[btokenOld_];

            // The ctoken must match the saved one.
            if (keccak256(abi.encode(_ctoken)) != keccak256(abi.encode(ctoken))) {
                revert VAULT_CTOKEN_MISMATCH();
            }

            delete bridgedToCanonical[btokenOld_];
            btokenDenylist[btokenOld_] = true;

            // Start the migration
            if (
                btokenOld_.supportsInterface(type(IBridgedERC20Migratable).interfaceId)
                    && _btokenNew.supportsInterface(type(IBridgedERC20Migratable).interfaceId)
            ) {
                IBridgedERC20Migratable(btokenOld_).changeMigrationStatus(_btokenNew, false);
                IBridgedERC20Migratable(_btokenNew).changeMigrationStatus(btokenOld_, true);
            }
        }

        bridgedToCanonical[_btokenNew] = _ctoken;
        canonicalToBridged[_ctoken.chainId][_ctoken.addr] = _btokenNew;
        lastMigrationStart[_ctoken.chainId][_ctoken.addr] = block.timestamp;

        emit BridgedTokenChanged({
            srcChainId: _ctoken.chainId,
            ctoken: _ctoken.addr,
            btokenOld: btokenOld_,
            btokenNew: _btokenNew,
            ctokenSymbol: _ctoken.symbol,
            ctokenName: _ctoken.name,
            ctokenDecimal: _ctoken.decimals
        });
    }
}
