// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @title ConfigureHoodiUSDCBridge
/// @notice Registers native USDC in the Taiko Hoodi ERC20 vault.
/// @dev By default this script runs as a fork-only dry-run using `vm.prank(vault.owner())`, which
/// works even when the owner is a contract such as the delegate controller. Set
/// `BROADCAST_CHANGES=1` and provide `ERC20_VAULT_OWNER_PRIVATE_KEY` only if the owner is an EOA.
/// @custom:security-contact security@taiko.xyz
contract ConfigureHoodiUSDCBridge is Script {
    address internal _l1UsdcToken;
    address internal _l2UsdcToken;
    address internal _erc20Vault;

    bool internal _broadcastChanges;
    uint256 internal _erc20VaultOwnerPrivateKey;

    function setUp() public {
        _l1UsdcToken = vm.envAddress("L1_USDC_TOKEN");
        _l2UsdcToken = vm.envAddress("L2_USDC_TOKEN");
        _erc20Vault = vm.envOr("ERC20_VAULT_ADDRESS", LibL2HoodiAddrs.HOODI_ERC20_VAULT);

        _broadcastChanges = vm.envOr("BROADCAST_CHANGES", uint256(0)) == 1;
        if (_broadcastChanges) {
            _erc20VaultOwnerPrivateKey = vm.envUint("ERC20_VAULT_OWNER_PRIVATE_KEY");
        }
    }

    function run() external returns (address previousBridgedToken_) {
        ERC20Vault vault = ERC20Vault(payable(_erc20Vault));
        address owner = vault.owner();

        ERC20Vault.CanonicalERC20 memory canonical = ERC20Vault.CanonicalERC20({
            chainId: uint64(LibNetwork.ETHEREUM_HOODI),
            addr: _l1UsdcToken,
            decimals: 6,
            symbol: "USDC",
            name: "USD Coin"
        });

        address currentBridgedToken = vault.canonicalToBridged(canonical.chainId, canonical.addr);
        require(
            currentBridgedToken == address(0) || currentBridgedToken == _l2UsdcToken,
            "conflicting canonical mapping"
        );

        if (_broadcastChanges) {
            address broadcaster = vm.addr(_erc20VaultOwnerPrivateKey);
            require(broadcaster == owner, "invalid owner key");
            vm.startBroadcast(_erc20VaultOwnerPrivateKey);
            previousBridgedToken_ = _apply(vault, canonical, currentBridgedToken);
            vm.stopBroadcast();
        } else {
            vm.startPrank(owner);
            previousBridgedToken_ = _apply(vault, canonical, currentBridgedToken);
            vm.stopPrank();
        }

        require(
            vault.canonicalToBridged(canonical.chainId, canonical.addr) == _l2UsdcToken,
            "mapping not registered"
        );
        require(!vault.paused(), "vault remains paused");

        (
            uint64 canonicalChainId,
            address canonicalAddress,
            uint8 canonicalDecimals,
            string memory canonicalSymbol,
            string memory canonicalName
        ) = vault.bridgedToCanonical(_l2UsdcToken);

        require(canonicalChainId == canonical.chainId, "invalid canonical chain");
        require(canonicalAddress == canonical.addr, "invalid canonical address");
        require(canonicalDecimals == canonical.decimals, "invalid canonical decimals");
        require(keccak256(bytes(canonicalSymbol)) == keccak256(bytes(canonical.symbol)), "invalid canonical symbol");
        require(keccak256(bytes(canonicalName)) == keccak256(bytes(canonical.name)), "invalid canonical name");

        console2.log("Configured Hoodi canonical USDC:", _l1UsdcToken);
        console2.log("Configured Hoodi bridged USDC:", _l2UsdcToken);
        console2.log("Configured Hoodi ERC20 vault:", _erc20Vault);
    }

    /// @dev Applies the bridged token mapping and ensures the vault is unpaused.
    function _apply(
        ERC20Vault _vault,
        ERC20Vault.CanonicalERC20 memory _canonical,
        address _currentBridgedToken
    )
        internal
        returns (address previousBridgedToken_)
    {
        if (_currentBridgedToken == address(0)) {
            previousBridgedToken_ = _vault.changeBridgedToken(_canonical, _l2UsdcToken);
        }

        if (_vault.paused()) {
            _vault.unpause();
        }
    }
}
